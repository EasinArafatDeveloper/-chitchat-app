import 'package:flutter/material.dart';
import 'call_screen.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<MockCall> calls = [
      MockCall(
        name: 'Sarah Mitchell',
        time: 'Today, 2:45 PM',
        incoming: true,
        video: false,
        missed: false,
      ),
      MockCall(
        name: 'Alex Chen',
        time: 'Yesterday, 11:20 AM',
        incoming: false,
        video: true,
        missed: false,
      ),
      MockCall(
        name: 'Ben Williams',
        time: 'May 22, 6:15 PM',
        incoming: true,
        video: false,
        missed: true,
      ),
      MockCall(
        name: 'Marcus R.',
        time: 'May 20, 9:02 AM',
        incoming: false,
        video: false,
        missed: false,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Calls',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: calls.length,
        itemBuilder: (context, index) {
          final call = calls[index];
          return Card(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF00A86B).withOpacity(0.1),
                child: Text(
                  call.name[0].toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF00A86B),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              title: Text(
                call.name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 15,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(
                    call.incoming
                        ? Icons.call_received_rounded
                        : Icons.call_made_rounded,
                    size: 14,
                    color: call.missed ? Colors.red : const Color(0xFF00A86B),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    call.time,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  call.video
                      ? Icons.videocam_rounded
                      : Icons.phone_rounded,
                  color: const Color(0xFF00A86B),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CallScreen(
                        name: call.name,
                        isVideo: call.video,
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class MockCall {
  final String name;
  final String time;
  final bool incoming;
  final bool video;
  final bool missed;

  MockCall({
    required this.name,
    required this.time,
    required this.incoming,
    required this.video,
    required this.missed,
  });
}
