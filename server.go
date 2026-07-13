// The MCP server: a health check and a demo greeting tool.
//
// A deliberately small MCP server — a good starting point for a new project or
// a demo. It exposes two tools:
//
//   - server_info — health/status of the server.
//   - greet       — a friendly greeting in one of a handful of languages,
//     defaulting to English (e.g. "greet in French" -> "Bonjour!").

package main

import (
	"context"
	"fmt"
	"os"
	"time"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

// version is the server version reported in the MCP handshake and by
// server_info. Overridable at build time with
// -ldflags "-X main.version=X.Y.Z"; make release keeps this literal in sync.
var version = "0.1.0"

// startTime is captured at process start for the uptime readout.
var startTime = time.Now()

// appName is the display name reported by server_info (override with APP_NAME).
func appName() string {
	if v := os.Getenv("APP_NAME"); v != "" {
		return v
	}
	return "mcp-hello-go-server"
}

// uptimeHHMMSS returns the server uptime as HH:MM:SS.
func uptimeHHMMSS() string {
	total := int(time.Since(startTime).Seconds())
	return fmt.Sprintf("%02d:%02d:%02d", total/3600, (total%3600)/60, total%60)
}

// serverInfoInput is the (empty) input for the server_info tool.
type serverInfoInput struct{}

// serverInfoResult is the structured result of the server_info tool.
type serverInfoResult struct {
	Status          string   `json:"status"`
	App             string   `json:"app"`
	Version         string   `json:"version"`
	Uptime          string   `json:"uptime"`
	Languages       []string `json:"languages"`
	DefaultLanguage string   `json:"default_language"`
	Source          string   `json:"source"`
	Author          string   `json:"author"`
}

// greetInput holds the greet tool's two optional arguments.
type greetInput struct {
	Language string `json:"language,omitempty" jsonschema:"A language name, alternate spelling, or ISO code (case-insensitive); omit to default to English. Supported: english, spanish, french, german, italian, portuguese, japanese, hawaiian."`
	Name     string `json:"name,omitempty" jsonschema:"Optional name to personalize the message (e.g. Bonjour, Alice!)."`
}

// handleServerInfo returns the health/status of the server.
func handleServerInfo(_ context.Context, _ *mcp.CallToolRequest, _ serverInfoInput) (*mcp.CallToolResult, serverInfoResult, error) {
	return nil, serverInfoResult{
		Status:          "OK",
		App:             appName(),
		Version:         version,
		Uptime:          uptimeHHMMSS(),
		Languages:       languages(),
		DefaultLanguage: defaultLanguage,
		Source:          "https://github.com/mitchallen/mcp-hello-go-server",
		Author:          "Mitch Allen (https://mitchallen.com)",
	}, nil
}

// handleGreet returns a friendly greeting in the requested language.
func handleGreet(_ context.Context, _ *mcp.CallToolRequest, input greetInput) (*mcp.CallToolResult, Greeting, error) {
	g, err := greet(input.Language, input.Name)
	if err != nil {
		// Unknown language -> a tool-level error (IsError), so the model can see
		// the message and self-correct rather than getting a protocol error.
		return &mcp.CallToolResult{
			IsError: true,
			Content: []mcp.Content{&mcp.TextContent{Text: err.Error()}},
		}, Greeting{}, nil
	}
	return nil, g, nil
}

// newServer builds the MCP server and registers the tools.
func newServer() *mcp.Server {
	server := mcp.NewServer(&mcp.Implementation{
		Name:    appName(),
		Version: version,
	}, &mcp.ServerOptions{
		Instructions: "A minimal demo MCP server. Use server_info for a health/status check, " +
			"and greet to get a friendly greeting in a given language (english, spanish, french, " +
			"german, italian, portuguese, japanese, or hawaiian; defaults to english). For " +
			"example, 'greet in French' returns 'Bonjour!'.",
	})

	mcp.AddTool(server, &mcp.Tool{
		Name:        "server_info",
		Description: "Health/status of the server: app name, version, uptime, and supported greeting languages.",
	}, handleServerInfo)

	mcp.AddTool(server, &mcp.Tool{
		Name: "greet",
		Description: "Return a friendly greeting in the requested language (default English). " +
			"language accepts a language name, alternate spelling, or ISO code (english, spanish, " +
			"french, german, italian, portuguese, japanese, hawaiian). Optional name personalizes " +
			"the message. Returns {language, greeting, message}.",
	}, handleGreet)

	return server
}
