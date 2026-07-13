// Console entry point for the hello MCP server.
//
// The transport is chosen by MCP_TRANSPORT:
//
//   - stdio (default) — for MCP clients that launch the server as a subprocess.
//   - http            — streamable HTTP on HOST:PORT (the container default),
//     serving the MCP endpoint at /mcp.
//
// Environment variables:
//
//	APP_NAME       display name reported by server_info (default: mcp-hello-go-server)
//	MCP_TRANSPORT  "stdio" (default) or "http"
//	HOST, PORT     bind address for the http transport (default: 127.0.0.1:8000)
package main

import (
	"context"
	"log"
	"net"
	"net/http"
	"os"

	"github.com/modelcontextprotocol/go-sdk/mcp"
)

func main() {
	// Log to stderr. The stdio transport owns stdout for the JSON-RPC stream, so
	// logs must never go there — a stray stdout write would corrupt the protocol.
	log.SetOutput(os.Stderr)

	transport := getenv("MCP_TRANSPORT", "stdio")
	switch transport {
	case "http":
		if err := runHTTP(); err != nil {
			log.Fatal(err)
		}
	case "stdio":
		if err := runStdio(); err != nil {
			log.Fatal(err)
		}
	default:
		log.Fatalf("unsupported MCP_TRANSPORT %q; expected 'stdio' or 'http'", transport)
	}
}

// runStdio serves over stdio: requests on stdin, responses on stdout.
func runStdio() error {
	server := newServer()
	log.Printf("starting %s over stdio", appName())
	return server.Run(context.Background(), &mcp.StdioTransport{})
}

// runHTTP serves over streamable HTTP, exposing the MCP endpoint at /mcp.
func runHTTP() error {
	addr := net.JoinHostPort(getenv("HOST", "127.0.0.1"), getenv("PORT", "8000"))
	server := newServer()

	handler := mcp.NewStreamableHTTPHandler(
		func(*http.Request) *mcp.Server { return server },
		nil,
	)
	mux := http.NewServeMux()
	mux.Handle("/mcp", handler)

	log.Printf("starting %s over streamable HTTP at http://%s/mcp", appName(), addr)
	return http.ListenAndServe(addr, mux)
}

// getenv returns the environment variable named key, or def if it is unset/empty.
func getenv(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}
