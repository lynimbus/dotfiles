package main

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	defaultHyMTEndpoint = "http://127.0.0.1:11435/v1/chat/completions"
	defaultHyMTModel    = "hy-mt2-1.8b"
	hyMTPromptPrefix    = "Translate the following text into Chinese. Note that you should only output the translated result without any additional explanation: "
)

// TranslatedEntry caches an auto-translated description alongside its source
// English text so upstream description changes invalidate stale entries.
type TranslatedEntry struct {
	Source string `json:"source"`
	Text   string `json:"text"`
}

func translationCachePath(locale string) string {
	dir, err := os.UserCacheDir()
	if err != nil || dir == "" {
		return ""
	}
	return filepath.Join(dir, "overview", fmt.Sprintf("translations-%s.json", locale))
}

func loadTranslationCache(path string) map[string]TranslatedEntry {
	out := make(map[string]TranslatedEntry)
	if path == "" {
		return out
	}
	raw, err := os.ReadFile(path)
	if err != nil || len(raw) == 0 {
		return out
	}
	var parsed map[string]TranslatedEntry
	if err := json.Unmarshal(raw, &parsed); err != nil {
		return out
	}
	for k, v := range parsed {
		if strings.TrimSpace(v.Source) != "" && strings.TrimSpace(v.Text) != "" {
			out[k] = v
		}
	}
	return out
}

func saveTranslationCache(path string, entries map[string]TranslatedEntry) error {
	if path == "" {
		return nil
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	raw, err := json.MarshalIndent(entries, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, append(raw, '\n'), 0o644)
}

var hyMTHTTPClient = &http.Client{
	Transport: &http.Transport{
		DialContext: (&net.Dialer{
			Timeout: 400 * time.Millisecond,
		}).DialContext,
	},
}

func translateWithHyMT(ctx context.Context, endpoint, model, sourceText string) (string, error) {
	src := strings.TrimSpace(sourceText)
	if src == "" {
		return "", nil
	}
	payload := map[string]any{
		"model": model,
		"messages": []map[string]string{
			{
				"role":    "user",
				"content": hyMTPromptPrefix + src,
			},
		},
		"temperature": 0.2,
		"max_tokens":  256,
		"stream":      false,
	}
	body, err := json.Marshal(payload)
	if err != nil {
		return "", err
	}

	reqCtx, cancel := context.WithTimeout(ctx, 8*time.Second)
	defer cancel()
	req, err := http.NewRequestWithContext(reqCtx, http.MethodPost, endpoint, bytes.NewReader(body))
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", "application/json")

	resp, err := hyMTHTTPClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return "", fmt.Errorf("hy-mt2 HTTP %d", resp.StatusCode)
	}

	var parsed struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&parsed); err != nil {
		return "", err
	}
	if len(parsed.Choices) == 0 {
		return "", errors.New("hy-mt2 returned no choices")
	}
	text := strings.TrimSpace(parsed.Choices[0].Message.Content)
	text = strings.Trim(text, `"'`)
	text = strings.TrimSpace(text)
	if text == "" {
		return "", errors.New("hy-mt2 returned blank translation")
	}
	return text, nil
}

func isTransportUnavailable(err error) bool {
	if err == nil {
		return false
	}
	var opErr *net.OpError
	if errors.As(err, &opErr) {
		return true
	}
	var netErr net.Error
	return errors.As(err, &netErr)
}
