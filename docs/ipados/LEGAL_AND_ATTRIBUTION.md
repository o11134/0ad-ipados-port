# Legal, attribution, and branding notes

## Required identity

Working name: **0 A.D. Touch — Unofficial Experimental iPad Port**.

The app and documentation must say:

- this is an unofficial experimental port and is not endorsed by Wildfire Games;
- it is not Age of Empires;
- Microsoft/Age of Empires code, assets, audio, names, and proprietary content are not included;
- upstream source/data/art/audio and third-party components remain under their existing licenses;
- source availability and complete attribution remain accessible.

The development bundle identifier defaults to `org.example.pyrogenesis.ipadshell`; it deliberately does
not claim an official Wildfire Games identity. Do not use the upstream `0ad.icns` or official logo as
the development icon until trademark/art permission is separately reviewed. A temporary original
icon is still required; none has been added yet.

## Repository evidence

`LICENSE.md` records GPL-2.0-or-later for the source code, GPL-2.0-or-later for binary-form data, and
CC BY-SA 3.0 as the principal art/audio license, with documented per-file/per-map/third-party
exceptions. It also identifies a permissive exception for `source/lib`. Preserve:

- `LICENSE.md` and `license_gpl-2.0.txt`;
- all relevant LGPL/MIT/other root license texts;
- `libraries/LICENSE.txt` and each dependency's notices;
- contributor acknowledgements and in-data credits/license metadata;
- source-revision and source-availability information.

Desktop `source/tools/dist/build-osx-bundle.py:119-123` copies selected text licenses but does not
establish an iOS notice bundle. The data staging manifest must explicitly retain asset/map/music/font
credits, even when producing a reduced POC package.

## Third-party review gates

The dependency inventory is not a legal bill of materials yet. Notable review items include
SpiderMonkey's MPL/GPL/LGPL mix, static OpenAL Soft under LGPL-2.0-or-later, gloox GPLv3 if ever
included, MoltenVK/its transitive notices, shader tools, fonts, codecs, and any vendored component
without an exact revision. Produce an archive-derived SPDX-style manifest before distribution.

Do not copy the macOS entitlements from `source/tools/dist/0ad.entitlements`; they include
`com.apple.security.cs.allow-unsigned-executable-memory` and network permissions that conflict with
the iPad proof's no-JIT/offline policy.

## About/source screen (later)

Before any build leaves a developer device, provide an in-app location containing the unofficial
notice, upstream project link, exact source revision/branch, source retrieval instructions, code/data
license summary, full third-party notices, asset credits, and contributors. The shell currently has
a temporary visible `Pyrogenesis iPad Shell` title and non-sensitive diagnostics; an About screen is
not implemented.

## Distribution boundary

This task authorizes local development installation only. Do not upload to TestFlight or the App
Store. Before any public distribution, obtain qualified review of GPL/source-distribution obligations
and Apple terms, CC BY-SA attribution/share-alike obligations, LGPL static-link/relinking obligations,
trademarks/logo/app-name/icon use, privacy/network declarations, export controls where relevant, and
all dependency/asset redistribution rights. This document records engineering evidence, not legal
advice or a compatibility conclusion.
