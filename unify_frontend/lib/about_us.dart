import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        title: const Text(
          'About Us',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                children: [
                  Icon(Icons.groups, size: 64, color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Unify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Connecting students through societies',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Mission section
            _SectionCard(
              icon: Icons.flag_outlined,
              title: 'Our Mission',
              content:
                  'Unify is a platform built to help University of Portsmouth students '
                  'discover, join, and engage with student societies. We believe that '
                  'university life is about more than just studying — it\'s about '
                  'building friendships, developing skills, and finding your community.',
            ),

            const SizedBox(height: 16),

            // What we offer section
            _SectionCard(
              icon: Icons.star_outline,
              title: 'What We Offer',
              content: null,
              child: const Column(
                children: [
                  _FeatureItem(
                    icon: Icons.search,
                    text: 'Browse and search all student societies in one place',
                  ),
                  _FeatureItem(
                    icon: Icons.rate_review_outlined,
                    text: 'Read and write honest reviews for any society',
                  ),
                  _FeatureItem(
                    icon: Icons.how_to_vote_outlined,
                    text: 'Participate in society polls and decisions',
                  ),
                  _FeatureItem(
                    icon: Icons.notifications_outlined,
                    text: 'Stay up to date with society news and events',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Team section
            _SectionCard(
              icon: Icons.people_outline,
              title: 'The Team',
              content:
                  'Unify was created by a team of University of Portsmouth students '
                  'as part of a software engineering project. Our goal was to build '
                  'a real, useful tool for the student community using modern '
                  'technologies including Flutter and Django.',
            ),

            const SizedBox(height: 16),

            // Contact section
            _SectionCard(
              icon: Icons.mail_outline,
              title: 'Contact Us',
              content:
                  'Have a question, suggestion, or spotted a bug? We\'d love to hear '
                  'from you.\n\nEmail: unify-support@placeholder.port.ac.uk\n'
                  'Website: www.placeholder-unify.port.ac.uk',
            ),

            const SizedBox(height: 32),

            Center(
              child: Text(
                '© 2026 Unify — University of Portsmouth',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? content;
  final Widget? child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.content,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            if (content != null)
              Text(
                content!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.6,
                    ),
              ),
            if (child != null) child!,
          ],
        ),
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.secondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}