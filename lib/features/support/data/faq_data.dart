import 'package:flutter/material.dart';

/// Single FAQ Item for Help Center
class FaqItem {
  final String category;
  final String question;
  final String answer;
  final IconData icon;
  final bool isCustomer;
  final bool isOwner;

  const FaqItem({
    required this.category,
    required this.question,
    required this.answer,
    required this.icon,
    this.isCustomer = true,
    this.isOwner = true,
  });
}

/// Comprehensive FAQ knowledge base for Customer and Salon Owner roles.
class FaqData {
  static const List<FaqItem> customerFaqs = [
    // 1. Joining a Queue
    FaqItem(
      category: 'Joining a Queue',
      icon: Icons.people_outline_rounded,
      question: 'How do I join a salon queue?',
      answer:
          'You can join a queue in two easy ways:\n1. Search for a salon on the Home screen, tap on it, select your desired grooming services, and tap "Join Live Queue".\n2. Scan the official QR code standee at the salon counter using the in-app scanner.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Joining a Queue',
      icon: Icons.access_time_rounded,
      question: 'How does the live queue work?',
      answer:
          'Once you join, SalonQueue assigns you a digital token (e.g. #A-01). The app tracks real-time progress, showing how many customers are ahead of you and the estimated waiting time in minutes.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Joining a Queue',
      icon: Icons.phonelink_ring_rounded,
      question: 'Can I join remotely from home or work?',
      answer:
          'Yes! You can join remotely from anywhere within your city. We recommend arriving at the salon approximately 5–10 minutes before your estimated turn time.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Joining a Queue',
      icon: Icons.notifications_active_outlined,
      question: 'How do I know when it is my turn?',
      answer:
          'When the stylist is ready, your digital ticket status updates to "IN CHAIR" with your designated Chair Number, and your phone will receive an instant high-priority alert and gentle haptic vibration.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Joining a Queue',
      icon: Icons.exit_to_app_rounded,
      question: 'Can I leave a queue after joining?',
      answer:
          'Yes. Open your active ticket on the "My Queue" tab and tap "Leave Queue / Cancel Token". Your spot will be freed up for other waiting customers.',
      isCustomer: true,
      isOwner: false,
    ),

    // 2. QR Code
    FaqItem(
      category: 'QR Code',
      icon: Icons.qr_code_scanner_rounded,
      question: 'How do I scan a SalonQueue QR?',
      answer:
          'Tap the center "Scan" button on the bottom navigation bar or in your Profile. Align the official counter QR standee inside the square viewfinder frame.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'QR Code',
      icon: Icons.verified_user_outlined,
      question: 'Why is my QR code not being accepted?',
      answer:
          'SalonQueue uses cryptographically signed QR codes. Random QR codes (Google, WhatsApp, Wi-Fi, UPI, or other apps) will be rejected to protect you from spoofed queues. Make sure you are scanning the official Salon Queue standee.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'QR Code',
      icon: Icons.warning_amber_rounded,
      question: 'What should I do if the QR code is invalid?',
      answer:
          'If the scanner displays "Invalid SalonQueue QR Code", ask the salon front desk to open their "Store Counter QR" screen or search the salon name directly in your Home tab.',
      isCustomer: true,
      isOwner: false,
    ),

    // 3. Bookings & Queue
    FaqItem(
      category: 'Bookings & Queue',
      icon: Icons.sync_problem_rounded,
      question: 'My queue position is not updating. What should I do?',
      answer:
          'Swipe down on the "My Queue" or "Home" tab to refresh the live status. If internet connectivity is weak, check your network and reopen the app.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Bookings & Queue',
      icon: Icons.confirmation_number_outlined,
      question: 'My token disappeared from the screen.',
      answer:
          'Tokens automatically move to "Bookings / History" once the service is marked completed by the stylist or if cancelled. Check the "Bookings" tab on the bottom bar to view past tokens.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Bookings & Queue',
      icon: Icons.store_mall_directory_outlined,
      question: 'I cannot join the queue — salon shows closed.',
      answer:
          'Salons can temporarily pause queues during rush hours or after closing time. Check the salon operating hours on their profile.',
      isCustomer: true,
      isOwner: false,
    ),

    // 4. Account
    FaqItem(
      category: 'Account',
      icon: Icons.lock_reset_rounded,
      question: 'How do I reset my password?',
      answer:
          'On the sign-in screen, tap "Forgot Password?", enter your registered email address, and follow the password reset link sent to your inbox.',
      isCustomer: true,
      isOwner: false,
    ),
    FaqItem(
      category: 'Account',
      icon: Icons.manage_accounts_outlined,
      question: 'How do I update my profile details?',
      answer:
          'Navigate to the "Profile" tab to review your name, phone number, and verified email address.',
      isCustomer: true,
      isOwner: false,
    ),

    // 5. Notifications
    FaqItem(
      category: 'Notifications',
      icon: Icons.notifications_none_rounded,
      question: 'I am not receiving my turn notification.',
      answer:
          'Ensure notifications and background alerts are enabled for SalonQueue in your Android Device Settings > Apps > Salon Queue > Notifications.',
      isCustomer: true,
      isOwner: false,
    ),

    // 6. Payments
    FaqItem(
      category: 'Payments',
      icon: Icons.account_balance_wallet_outlined,
      question: 'How are payments handled?',
      answer:
          'All payments are collected directly at the salon counter (Cash, UPI, Card) after your grooming service is completed.',
      isCustomer: true,
      isOwner: false,
    ),
  ];

  static const List<FaqItem> ownerFaqs = [
    // 1. Queue Management
    FaqItem(
      category: 'Queue Management',
      icon: Icons.toggle_on_rounded,
      question: 'How to open/pause the salon queue?',
      answer:
          'On your Owner Dashboard, toggle the top Master Queue Banner switch. When green (QUEUE IS OPEN), customers can join. When red (QUEUE IS PAUSED), incoming new tokens are stopped.',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Queue Management',
      icon: Icons.person_add_alt_1_rounded,
      question: 'How to add a walk-in customer without phone?',
      answer:
          'Tap "+ Add Walk-in" button or the floating action button. Enter customer name, phone (optional), select their requested services, and tap "Generate Token".',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Queue Management',
      icon: Icons.event_seat_rounded,
      question: 'How to serve the next customer (Call to Chair)?',
      answer:
          'In the "Live Queue" section, tap "Call Next / Sit". The system automatically assigns the customer to an available chair (e.g. Chair #1) and alerts their phone.',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Queue Management',
      icon: Icons.check_circle_outline_rounded,
      question: 'How to complete a service and free up a chair?',
      answer:
          'In the "Currently Serving (In Chair)" card, tap the green "Finish" button once the haircut/grooming is complete. The chair becomes immediately available.',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Queue Management',
      icon: Icons.skip_next_rounded,
      question: 'How to skip or cancel an absent customer?',
      answer:
          'In the Live Queue list, tap "Skip" if the customer is temporarily absent, or "Cancel" to permanently remove their ticket from the line.',
      isCustomer: false,
      isOwner: true,
    ),

    // 2. Salon Profile & Location
    FaqItem(
      category: 'Salon Profile',
      icon: Icons.storefront_rounded,
      question: 'How to update salon address, district & state?',
      answer:
          'Open "Salon Profile" from the Quick Operations hub or bottom navigation. Update your state, district, city, street address, and active chair capacity, then tap "Save Store Changes".',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Salon Profile',
      icon: Icons.menu_book_rounded,
      question: 'How to add or edit services & pricing?',
      answer:
          'Go to "Services & Pricing" tab. Tap "+ Add Service" to specify service name, category (Hair, Beard, Facial, Spa), price (₹), and estimated duration in minutes.',
      isCustomer: false,
      isOwner: true,
    ),

    // 3. Salon QR Code
    FaqItem(
      category: 'Salon QR Code',
      icon: Icons.qr_code_2_rounded,
      question: 'How to display and print the Store Counter QR?',
      answer:
          'Tap "Store QR" in your Owner Dashboard. The screen renders your authentic Salon Queue standee with cryptographic verification. Tap "Print QR Code Standee" to print for your front desk.',
      isCustomer: false,
      isOwner: true,
    ),
    FaqItem(
      category: 'Salon QR Code',
      icon: Icons.security_rounded,
      question: 'Why do customers need our official QR code?',
      answer:
          'The SalonQueue app cryptographically validates QR payloads to prevent fake or duplicate bookings. Customers can only join by scanning your official standee.',
      isCustomer: false,
      isOwner: true,
    ),

    // 4. Analytics & Revenue
    FaqItem(
      category: 'Business Analytics',
      icon: Icons.analytics_outlined,
      question: 'Where can I see daily revenue and completed cuts?',
      answer:
          'Tap the "Analytics" tab on your dashboard. It displays collected revenue today, in-chair counts, waiting metrics, and a percentage breakdown of top requested services.',
      isCustomer: false,
      isOwner: true,
    ),

    // 5. Account & Security
    FaqItem(
      category: 'Account & Security',
      icon: Icons.admin_panel_settings_outlined,
      question: 'How to manage login credentials and logout?',
      answer:
          'Tap the Sign Out icon in the top right app bar anytime. To change password, use the "Forgot Password" link on the sign-in screen.',
      isCustomer: false,
      isOwner: true,
    ),
  ];
}
