# Networking after the offline proof of concept

## MVP policy

Multiplayer, lobby, NAT traversal, matchmaking, login, background sessions, and notifications are out
of scope through M10. The application must launch, show the menu, load a small map, play, save, and
load without a network connection. Network code stays in the repository behind flags; it is not
deleted.

Existing flags are insufficient to claim a network-free binary. `CONFIG2_LOBBY` and
`CONFIG2_MINIUPNPC` default on (`source/lib/config2.h:83-90`) and Premake provides
`--without-lobby`/`--without-miniupnpc` (`build/premake/premake5.lua:60-61,287-293`). However,
`source/ps/GameSetup/GameSetup.cpp:568-587` still initializes `CNetHost` and curl, ENet initializes in
`source/network/NetHost.cpp:74-82`, and direct host/join APIs are exposed independently of the lobby
in `source/network/scripting/JSInterface_Network.cpp:78-142,289-309`.

Add a narrow `CONFIG2_OFFLINE_MVP`/`CONFIG2_NETWORK` policy that prevents ENet, curl/user reporter,
profiler HTTP, lobby, UPnP, mod.io/import/update flows, and JS host/join registration from initializing
or entering the iPad link closure. Hide corresponding UI. Verify by source/link inspection and an
offline device run; flags alone are not proof.

## Post-M10 questions

Only after the offline proof is stable, separately evaluate:

- LAN discovery and direct IP over IPv4/IPv6;
- iPadOS local-network permission UX and denial behavior;
- network interface/route changes and Wi-Fi/cellular policy;
- suspension while hosting/joined and explicit disconnect semantics;
- deterministic simulation and exact cross-platform protocol/version compatibility;
- ENet behavior, socket limits, TLS chain, certificate store, and thread shutdown on iPadOS;
- lobby/account privacy and GPL-compatible service/client distribution;
- whether background networking is needed (default answer for the game MVP is no);
- Bonjour or other discovery only through public APIs and only with declared purpose strings;
- reproducible security updates without runtime executable/native/remote-script downloading.

No networking compile, socket test, permission request, or packet capture occurred in this session.
