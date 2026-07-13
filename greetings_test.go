package main

import (
	"strings"
	"testing"
)

func TestDefaultLanguageIsEnglish(t *testing.T) {
	if defaultLanguage != "english" {
		t.Fatalf("defaultLanguage = %q, want english", defaultLanguage)
	}
	for _, in := range []string{"", "   "} {
		got, err := resolveLanguage(in)
		if err != nil || got != "english" {
			t.Fatalf("resolveLanguage(%q) = %q, %v; want english, nil", in, got, err)
		}
	}
}

func TestResolveIsCaseInsensitive(t *testing.T) {
	cases := map[string]string{"French": "french", "  SPANISH  ": "spanish"}
	for in, want := range cases {
		if got, err := resolveLanguage(in); err != nil || got != want {
			t.Fatalf("resolveLanguage(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
}

func TestResolveAcceptsAliasesAndCodes(t *testing.T) {
	cases := map[string]string{"fr": "french", "es": "spanish", "jp": "japanese", "Français": "french"}
	for in, want := range cases {
		if got, err := resolveLanguage(in); err != nil || got != want {
			t.Fatalf("resolveLanguage(%q) = %q, %v; want %q", in, got, err, want)
		}
	}
}

func TestResolveUnknownLanguageErrors(t *testing.T) {
	_, err := resolveLanguage("klingon")
	if err == nil {
		t.Fatal("expected an error for an unknown language")
	}
	// The error lists the supported languages so a caller can recover.
	if !strings.Contains(err.Error(), "supported") || !strings.Contains(err.Error(), "english") {
		t.Fatalf("error %q should list supported languages", err)
	}
}

func TestGreetDefaultsToEnglish(t *testing.T) {
	g, err := greet("", "")
	if err != nil {
		t.Fatal(err)
	}
	if g.Language != "english" || g.Greeting != "Hello" || g.Message != "Hello!" {
		t.Fatalf("greet(\"\",\"\") = %+v", g)
	}
}

func TestGreetInFrench(t *testing.T) {
	g, _ := greet("French", "")
	if g.Language != "french" || g.Message != "Bonjour!" {
		t.Fatalf("greet(French) = %+v", g)
	}
}

func TestGreetPersonalized(t *testing.T) {
	g, _ := greet("french", "Alice")
	if g.Message != "Bonjour, Alice!" {
		t.Fatalf("greet(french, Alice).Message = %q", g.Message)
	}
}
