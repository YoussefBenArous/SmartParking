import 'package:flutter/material.dart';
import 'package:another_dashed_container/another_dashed_container.dart';

class ParkingSlot extends StatelessWidget {
  final bool? isParked;
  final bool? isBooked;
  final String? slotName;
  final String slotId;
  final String time;
  final VoidCallback? onTap;
  final bool isReserved;
  final DateTime? reservationExpiry;

  const ParkingSlot({
    Key? key,
    this.isParked,
    this.isBooked,
    this.slotName,
    required this.slotId,
    required this.time,
    this.onTap,
    this.isReserved = false,
    this.reservationExpiry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: DashedContainer(
        dashColor: Colors.blue.shade300,
        dashedLength: 10.0,
        blankLength: 9.0,
        strokeWidth: 1.0,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8), // Reduced padding
              width: 180,
              height: 130, // Increased height to accommodate content
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Colors.blue.shade100,
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min, // Use minimum space
                children: [
                  _buildHeader(),
                  Divider(
                    color: Colors.blue.shade100,
                    thickness: 1,
                    height: 12, // Reduced divider height
                  ),
                  Expanded(child: _buildSlotContent()), // Wrap in Expanded
                ],
              ),
            ),
            if (!isBooked!)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    5,
                    (index) => Container(
                      height: 12, // Reduced line height
                      width: 2,
                      color: Colors.blue.shade100,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTimeWidget(),
        _buildSlotNameBadge(),
        const SizedBox(width: 30), // Placeholder for symmetry
      ],
    );
  }

  Widget _buildTimeWidget() {
    return time.isEmpty
        ? const SizedBox(width: 1)
        : Text(
            time,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          );
  }

  Widget _buildSlotNameBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 15),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blue.shade100),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        slotName ?? '',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSlotContent() {
    final bool isSpotOccupied = isBooked == true || isReserved;

    if (isSpotOccupied) {
      return Container(
        height: 65, // Fixed height for occupied spots
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Image.asset(
              "assets/images/car.png",
              height: 35, // Reduced image size
              width: 65,
              fit: BoxFit.contain,
            ),
            if (reservationExpiry != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Text(
                    'Until: ${_formatTime(reservationExpiry!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      height: 65, // Same height as occupied spots
      child: Center(
        child: _buildBookButton(),
      ),
    );
  }

  Widget _buildBookButton() {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0XFF0079C0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          "BOOK",
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
