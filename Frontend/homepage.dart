import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final CarouselController _carouselController = CarouselController();
  int _currentCarouselIndex = 0;

  // Top 3 popular societies - structured to easily add images later
  final List<Map<String, String>> popularSocieties = [
    {
      'name': 'Art Society',
      'image': '', // Placeholder for future image path
    },
    {
      'name': 'Anime Society',
      'image': '', // Placeholder for future image path
    },
    {
      'name': 'Gaming Society',
      'image': '', // Placeholder for future image path
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Unify',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Navigate to About Us page
            },
            child: const Text(
              'About us',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            // Hero Carousel Section
            _buildHeroCarousel(),
            const SizedBox(height: 40),
            // Call to Action Button
            _buildJoinButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCarousel() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Popular Societies',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 20),
        CarouselSlider.builder(
          carouselController: _carouselController,
          itemCount: popularSocieties.length,
          itemBuilder: (context, index, realIndex) {
            final society = popularSocieties[index];
            return _buildCarouselItem(society);
          },
          options: CarouselOptions(
            height: 300,
            aspectRatio: 16 / 9,
            viewportFraction: 0.8,
            initialPage: 0,
            enableInfiniteScroll: true,
            reverse: false,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 3),
            autoPlayAnimationDuration: const Duration(milliseconds: 800),
            autoPlayCurve: Curves.fastOutSlowIn,
            enlargeCenterPage: true,
            enlargeFactor: 0.3,
            onPageChanged: (index, reason) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            scrollDirection: Axis.horizontal,
          ),
        ),
        const SizedBox(height: 20),
        // Carousel indicators
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children:
              popularSocieties.asMap().entries.map((entry) {
                return Container(
                  width: 8.0,
                  height: 8.0,
                  margin: const EdgeInsets.symmetric(horizontal: 4.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        _currentCarouselIndex == entry.key
                            ? Colors.deepPurple
                            : Colors.grey.shade400,
                  ),
                );
              }).toList(),
        ),
      ],
    );
  }

  Widget _buildCarouselItem(Map<String, String> society) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.deepPurple.shade300, Colors.deepPurple.shade600],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade400,
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Placeholder for future image
          if (society['image']!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                society['image']!,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          // Society name overlay
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                society['name']!,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton() {
    return ElevatedButton(
      onPressed: () {
        // TODO: Navigate to societies page or sign up page
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
      child: const Text(
        'Join a society today',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}
