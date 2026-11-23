package main

import (
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/egoist/mygo"
	"github.com/egoist/mygo/ui"
)

// Injected via -ldflags at build time by pkgs/overview.nix.
var (
	appVersion      = "0.1.0"
	defaultRepoRoot = ""
)

func main() {
	showVersion := flag.Bool("version", false, "print version and exit")
	repoFlag := flag.String("repo", "", "path to the dotfiles flake repository (for live refresh)")
	dataFlag := flag.String("data", "", "path to a snapshot JSON file instead of embedded/cached data")
	flag.Parse()

	if *showVersion {
		fmt.Printf("overview %s\n", appVersion)
		return
	}

	tr, err := loadI18n()
	if err != nil {
		log.Fatalf("load i18n: %v", err)
	}

	snap, modTime, live, err := loadInitialSnapshot(*dataFlag)
	if err != nil {
		log.Fatalf("load snapshot: %v", err)
	}

	repoRoot := resolveRepoRoot(*repoFlag, defaultRepoRoot)
	app := newOverviewApp(snap, tr, repoRoot, modTime, live, true)

	mygo.App.WhenReady(func() {
		win := mygo.NewWindow(mygo.WindowOptions{
			Title:     app.t("app.title", map[string]any{"host": snap.Meta.Hostname}),
			Width:     1240,
			Height:    840,
			MinWidth:  680,
			MinHeight: 520,
			StateKey:  "overview-main",
			Content:   ui.View(app.view),
		})
		app.win = win
		app.lastWinTitle = app.t("app.title", map[string]any{"host": snap.Meta.Hostname})
		// Automatically refresh from the live flake in the background on launch
		// while immediately showing the cached/embedded snapshot.
		if *dataFlag == "" && repoRoot != "" {
			app.triggerRefresh(nil, true)
		}
		app.triggerTranslateMissing()
	})

	if err := mygo.App.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "overview: %v\n", err)
		os.Exit(1)
	}
}
