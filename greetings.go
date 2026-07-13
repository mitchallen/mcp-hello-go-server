// Greeting data for the demo `greet` tool.
//
// Maps a handful of languages to a greeting word. Lookups are case-insensitive
// and also accept common alternate spellings / ISO codes (e.g. "fr" or
// "Français" for French). Add a language by adding a row to greetings (and,
// optionally, an alias to aliases).

package main

import (
	"fmt"
	"strings"
)

// langWord pairs a canonical language name with its greeting word. A slice
// (not a map) so the order is stable — server_info reports the set in this
// order.
type langWord struct {
	name string
	word string
}

// greetings is the canonical language -> greeting word list, in definition order.
var greetings = []langWord{
	{"english", "Hello"},
	{"spanish", "Hola"},
	{"french", "Bonjour"},
	{"german", "Hallo"},
	{"italian", "Ciao"},
	{"portuguese", "Olá"},
	{"japanese", "こんにちは (Konnichiwa)"},
	{"hawaiian", "Aloha"},
}

// defaultLanguage is used when the caller doesn't specify one.
const defaultLanguage = "english"

// aliases maps alternate spellings / ISO codes to a canonical language name.
var aliases = map[string]string{
	"en":        "english",
	"es":        "spanish",
	"espanol":   "spanish",
	"español":   "spanish",
	"fr":        "french",
	"francais":  "french",
	"français":  "french",
	"de":        "german",
	"deutsch":   "german",
	"it":        "italian",
	"italiano":  "italian",
	"pt":        "portuguese",
	"portugues": "portuguese",
	"português": "portuguese",
	"ja":        "japanese",
	"jp":        "japanese",
	"nihongo":   "japanese",
	"haw":       "hawaiian",
}

// languages returns the languages this server knows how to greet in, in
// definition order.
func languages() []string {
	out := make([]string, len(greetings))
	for i, g := range greetings {
		out[i] = g.name
	}
	return out
}

// greetingWord returns the greeting word for a canonical language name.
func greetingWord(canonical string) (string, bool) {
	for _, g := range greetings {
		if g.name == canonical {
			return g.word, true
		}
	}
	return "", false
}

// Greeting is a successful greet result: {language, greeting, message}.
type Greeting struct {
	Language string `json:"language"`
	Greeting string `json:"greeting"`
	Message  string `json:"message"`
}

// resolveLanguage returns the canonical language name for language.
//
// It accepts a canonical name, an alias, or an ISO code (case-insensitive). A
// blank value yields the default (English). It returns an error listing the
// supported set for an unknown language.
func resolveLanguage(language string) (string, error) {
	key := strings.ToLower(strings.TrimSpace(language))
	if key == "" {
		return defaultLanguage, nil
	}
	if _, ok := greetingWord(key); ok {
		return key, nil
	}
	if canonical, ok := aliases[key]; ok {
		return canonical, nil
	}
	return "", fmt.Errorf("unknown language '%s'; supported: %s",
		language, strings.Join(languages(), ", "))
}

// greet builds a Greeting for language (default English). Pass a non-empty name
// to personalize the message (e.g. "Bonjour, Alice!").
func greet(language, name string) (Greeting, error) {
	canonical, err := resolveLanguage(language)
	if err != nil {
		return Greeting{}, err
	}
	word, _ := greetingWord(canonical)
	name = strings.TrimSpace(name)
	message := word + "!"
	if name != "" {
		message = fmt.Sprintf("%s, %s!", word, name)
	}
	return Greeting{Language: canonical, Greeting: word, Message: message}, nil
}
