# Open-source design references

The snow effect's bounded height-column piles, window-motion shedding and
front-to-back geometry approach were informed by SnowDesk:

- https://github.com/iystoychev/snowdesk
- inspected commit: 9b0053dbf63d384a36bddf9eea100b979474be24
- references: snow/sim.go and overlay_darwin.m

DockCity's Swift implementation and integration are separate from SnowDesk's
Go/cgo runtime. No SnowDesk artwork, sound or executable is bundled.
Its MIT notice is retained here for attribution:

MIT License

Copyright (c) 2026 Ivan Stoychev

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
