# ScreenToText — build / install / uninstall

PREFIX      ?= $(HOME)/Applications/ScreenToText
BIN          = screentotext
SRC          = main.swift
LABEL        = com.$(USER).screentotext
PLIST        = $(HOME)/Library/LaunchAgents/$(LABEL).plist
SWIFTC      ?= /usr/bin/swiftc
SWIFTFLAGS   = -O -framework AppKit -framework Carbon -framework Vision
# Signing identity. Ad-hoc ("-") signatures change on every rebuild, which makes
# macOS forget the Screen Recording permission. A real certificate keeps it stable.
SIGN_ID     ?= $(shell security find-identity -p codesigning -v 2>/dev/null | awk -F'"' '/Apple Development|Developer ID Application/ {print $$2; exit}')
ifeq ($(SIGN_ID),)
SIGN_ID      = -
endif

.PHONY: all build install load unload uninstall clean reinstall status

all: build

build: $(BIN)

$(BIN): $(SRC)
	$(SWIFTC) $(SWIFTFLAGS) -o $(BIN) $(SRC)
	codesign --force --sign "$(SIGN_ID)" --identifier $(LABEL) $(BIN)

install: build
	mkdir -p $(PREFIX)
	cp $(BIN) $(PREFIX)/$(BIN)
	@printf '%s\n' \
'<?xml version="1.0" encoding="UTF-8"?>' \
'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
'<plist version="1.0">' \
'<dict>' \
'    <key>Label</key><string>$(LABEL)</string>' \
'    <key>ProgramArguments</key><array><string>$(PREFIX)/$(BIN)</string></array>' \
'    <key>RunAtLoad</key><true/>' \
'    <key>KeepAlive</key><true/>' \
'    <key>ProcessType</key><string>Interactive</string>' \
'    <key>StandardOutPath</key><string>/tmp/screentotext.log</string>' \
'    <key>StandardErrorPath</key><string>/tmp/screentotext.err</string>' \
'</dict>' \
'</plist>' > $(PLIST)
	$(MAKE) load

load:
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null
	launchctl bootstrap gui/$$(id -u) $(PLIST)

unload:
	-launchctl bootout gui/$$(id -u)/$(LABEL) 2>/dev/null

uninstall: unload
	rm -f $(PLIST) $(PREFIX)/$(BIN)
	-rmdir $(PREFIX) 2>/dev/null || true

reinstall: uninstall install

status:
	@launchctl print gui/$$(id -u)/$(LABEL) 2>/dev/null | grep -E "state|pid" | head -4 || echo "not loaded"

clean:
	rm -f $(BIN)
