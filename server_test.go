// Tests for the MCP tool layer, driven through an in-memory client.
//
// A server and a client are connected over an in-process pair of transports
// (mcp.NewInMemoryTransports) — the Go analog of the Python suite's in-memory
// FastMCP client. No network, no subprocess.

package main

import (
	"context"
	"strings"
	"testing"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

// connect wires a fresh server to a client over in-memory transports and
// returns the connected client session plus a cleanup func.
func connect(t *testing.T) (context.Context, *mcp.ClientSession) {
	t.Helper()
	ctx := context.Background()
	serverT, clientT := mcp.NewInMemoryTransports()

	ss, err := newServer().Connect(ctx, serverT, nil)
	if err != nil {
		t.Fatalf("server connect: %v", err)
	}
	client := mcp.NewClient(&mcp.Implementation{Name: "test", Version: "0"}, nil)
	cs, err := client.Connect(ctx, clientT, nil)
	if err != nil {
		t.Fatalf("client connect: %v", err)
	}
	t.Cleanup(func() {
		cs.Close()
		ss.Close()
	})
	return ctx, cs
}

// callStruct calls a tool and returns its structured content as a generic map.
func callStruct(t *testing.T, ctx context.Context, cs *mcp.ClientSession, name string, args map[string]any) map[string]any {
	t.Helper()
	res, err := cs.CallTool(ctx, &mcp.CallToolParams{Name: name, Arguments: args})
	if err != nil {
		t.Fatalf("call %s: %v", name, err)
	}
	if res.IsError {
		t.Fatalf("call %s returned IsError; content=%v", name, res.Content)
	}
	m, ok := res.StructuredContent.(map[string]any)
	if !ok {
		t.Fatalf("call %s: StructuredContent is %T, want map", name, res.StructuredContent)
	}
	return m
}

func TestToolsAreRegistered(t *testing.T) {
	ctx, cs := connect(t)
	res, err := cs.ListTools(ctx, nil)
	if err != nil {
		t.Fatal(err)
	}
	got := map[string]bool{}
	for _, tool := range res.Tools {
		got[tool.Name] = true
	}
	if !got["server_info"] || !got["greet"] || len(got) != 2 {
		t.Fatalf("registered tools = %v, want {server_info, greet}", got)
	}
}

func TestServerInfoReportsStatusAndMetadata(t *testing.T) {
	ctx, cs := connect(t)
	info := callStruct(t, ctx, cs, "server_info", nil)
	if info["status"] != "OK" {
		t.Errorf("status = %v, want OK", info["status"])
	}
	if info["default_language"] != "english" {
		t.Errorf("default_language = %v", info["default_language"])
	}
	if info["source"] != "https://github.com/mitchallen/mcp-hello-go-server" {
		t.Errorf("source = %v", info["source"])
	}
	if v, _ := info["version"].(string); v == "" {
		t.Error("version is empty")
	}
	langs, _ := info["languages"].([]any)
	found := false
	for _, l := range langs {
		if l == "english" {
			found = true
		}
	}
	if !found {
		t.Errorf("languages %v missing english", langs)
	}
}

func TestGreetDefaultsToEnglishTool(t *testing.T) {
	ctx, cs := connect(t)
	g := callStruct(t, ctx, cs, "greet", map[string]any{})
	if g["language"] != "english" || g["message"] != "Hello!" {
		t.Fatalf("greet{} = %v", g)
	}
}

func TestGreetInFrenchTool(t *testing.T) {
	ctx, cs := connect(t)
	g := callStruct(t, ctx, cs, "greet", map[string]any{"language": "French"})
	if g["language"] != "french" || g["message"] != "Bonjour!" {
		t.Fatalf("greet{French} = %v", g)
	}
}

func TestGreetPersonalizedTool(t *testing.T) {
	ctx, cs := connect(t)
	g := callStruct(t, ctx, cs, "greet", map[string]any{"language": "spanish", "name": "Alice"})
	if g["language"] != "spanish" || g["message"] != "Hola, Alice!" {
		t.Fatalf("greet{spanish,Alice} = %v", g)
	}
}

func TestGreetUnknownLanguageErrors(t *testing.T) {
	ctx, cs := connect(t)
	res, err := cs.CallTool(ctx, &mcp.CallToolParams{
		Name:      "greet",
		Arguments: map[string]any{"language": "klingon"},
	})
	if err != nil {
		t.Fatalf("call greet: %v", err)
	}
	if !res.IsError {
		t.Fatal("expected IsError for an unknown language")
	}
	text := ""
	if len(res.Content) > 0 {
		if tc, ok := res.Content[0].(*mcp.TextContent); ok {
			text = tc.Text
		}
	}
	if !strings.Contains(text, "unknown language") {
		t.Fatalf("error content = %q, want to contain 'unknown language'", text)
	}
}
