import 'package:flutter/material.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/widget/CustomPage.dart';
import 'package:smart_parking/widget/button.dart';

class FirstPage extends StatefulWidget {
  const FirstPage({super.key});

  @override
  State<FirstPage> createState() => _FirstPageState();
}

class _FirstPageState extends State<FirstPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    final List<Widget> _pages = [
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 50,
          ),
          CustomPage(
            imagepath: "assets/images/First.jpg",
            title: "Your Park",
            text: "Make it smarter",
            height: screenHeight * 0.4,
            width: screenWidth * 0.8,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            top: screenHeight * 0.1,
            fontsize: 32,
          ),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
          ),
          CustomPage(
            imagepath: "assets/images/Second.jpg",
            title: "Be mindful of others' space and circumstances",
            height: screenHeight * 0.4,
            width: screenWidth * 0.8,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            top: screenHeight * 0.1,
            fontsize: 20,
          ),
        ],
      ),
      Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            height: 30,
          ),
          CustomPage(
            imagepath: "assets/images/RUN.png",
            title: "Search, Pick \n & Park",
            text: "Book Your Parking Spot Anytime, Anywhere",
            height: screenHeight * 0.4,
            width: screenWidth * 0.8,
            left: screenWidth * 0.1,
            right: screenWidth * 0.1,
            top: screenHeight * 0.1,
            fontsize: 24,
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: _pages,
          ),
          if (_currentPage != _pages.length - 1)
            Positioned(
              bottom: screenHeight * 0.03,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: List.generate(
                  _pages.length,
                  (index) => _buildDot(index),
                ),
              ),
            ),
          if (_currentPage == _pages.length - 1)
            Positioned(
              top: screenHeight * 0.7,
              left: screenWidth * 0.1,
              height: 200,
              width: screenWidth * 0.8,
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    button(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => LoginPage(),
                            ),
                          );
                        },
                        text: "Start Now",
                        fontsize: 15,
                        width: 133,
                        height: 53,
                        radius: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return Container(
      height: 10,
      width: 10,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _currentPage == index ? Colors.blue : Colors.grey,
      ),
    );
  }
}
