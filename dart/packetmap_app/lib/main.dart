import 'package:flutter/material.dart';

import 'src/app_state.dart';
import 'src/aprs_client.dart';
import 'src/theme.dart';
import 'src/ui/heard_page.dart';
import 'src/ui/map_page.dart';
import 'src/ui/messages_page.dart';
import 'src/ui/raw_page.dart';
import 'src/ui/setup_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PacketMapApp());
}

class PacketMapApp extends StatefulWidget {
  const PacketMapApp({super.key});

  @override
  State<PacketMapApp> createState() => _PacketMapAppState();
}

class _PacketMapAppState extends State<PacketMapApp> with WidgetsBindingObserver {
  final state = AppState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    state.start();
  }

  /// A suspended process can leave a dead socket looking open, so verify the
  /// link on the way back in rather than trusting it.
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) state.onResume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) => MaterialApp(
        title: 'PacketMap',
        debugShowCheckedModeBanner: false,
        theme: obsidianTheme(light: state.settings.light),
        home: HomeShell(state: state),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.state});
  final AppState state;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = [
      MapPage(state: s),
      HeardPage(state: s),
      MessagesPage(state: s),
      RawPage(state: s),
      SetupPage(state: s),
    ];
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(58),
        child: _Header(state: s),
      ),
      body: Stack(
        children: [
          IndexedStack(index: tab, children: pages),
          if (s.banner != null)
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: _Toast(text: s.banner!, light: s.settings.light),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 62,
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.my_location), label: 'Map'),
          const NavigationDestination(icon: Icon(Icons.list), label: 'Heard'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: s.messages.unreadCount > 0,
              label: Text('${s.messages.unreadCount}'),
              child: const Icon(Icons.mail_outline),
            ),
            label: 'Msgs',
          ),
          const NavigationDestination(icon: Icon(Icons.show_chart), label: 'Raw'),
          const NavigationDestination(icon: Icon(Icons.settings), label: 'Setup'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final light = state.settings.light;
    final amber = light ? Ob.lAmber : Ob.amber;
    final dim = light ? Ob.lInkDim : Ob.inkDim;
    final (dot, label) = switch (state.link) {
      LinkState.loggedIn => (
          light ? Ob.lGreen : Ob.green,
          state.settings.myCall.isEmpty
              ? 'RX ONLY (NO CALLSIGN)'
              : '${state.settings.myCall} ${state.client.verified ? 'VERIFIED' : 'RX ONLY'}'
        ),
      LinkState.connecting => (amber, 'CONNECTING…'),
      LinkState.offline => (light ? Ob.lRed : Ob.red, 'OFFLINE'),
    };
    return SafeArea(
      bottom: false,
      child: Container(
        color: light ? Ob.lNavBg : Ob.navBg,
        padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('PACKETMAP',
                      style: TextStyle(
                          color: amber,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          letterSpacing: 4)),
                  const SizedBox(height: 2),
                  Row(children: [
                    Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(label,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10, color: dim, letterSpacing: 1)),
                    ),
                  ]),
                ],
              ),
            ),
            if (state.settings.tx)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: state.canTx ? (light ? Ob.lGreen : Ob.green) : Ob.red,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('TX',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: light ? Colors.white : const Color(0xFF03110D))),
              ),
            IconButton(
              icon: Icon(light ? Icons.dark_mode : Icons.light_mode, color: amber),
              tooltip: 'Toggle theme',
              onPressed: () {
                state.settings.light = !light;
                state.settings.save();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Toast extends StatelessWidget {
  const _Toast({required this.text, required this.light});
  final String text;
  final bool light;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: light ? Ob.lPanel : Ob.panel,
          border: Border.all(color: light ? Ob.lAmber : Ob.amberDim),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: light ? Ob.lAmber : Ob.amber)),
      ),
    );
  }
}
