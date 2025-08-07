import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../app_provider.dart';
import 'qr_management_screen.dart';
import 'security_logs_screen.dart';

class SecurityDashboard extends StatefulWidget {
  const SecurityDashboard({super.key});

  @override
  State<SecurityDashboard> createState() => _SecurityDashboardState();
}

class _SecurityDashboardState extends State<SecurityDashboard> {
  int _selectedIndex = 0;
  final PageController _pageController = PageController();

  // Dashboard statistics
  int _studentsOnCampus = 0;
  int _todayExits = 0;
  int _todayReturns = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    // Load user data and dashboard stats
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeSecurityDashboard();
    });
  }

  Future<void> _initializeSecurityDashboard() async {
    final provider = Provider.of<AppProvider>(context, listen: false);
    await provider.loadUserData(); // Load user data first
    await _loadDashboardStats(); // Then load dashboard stats
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardStats() async {
    setState(() => _isLoadingStats = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final currentUser = provider.getCurrentUser();

      debugPrint('Security Dashboard - Current User: $currentUser');
      debugPrint('Security Dashboard - User Role: ${currentUser?.role}');
      debugPrint('Security Dashboard - User ID: ${currentUser?.id}');
      debugPrint('Security Dashboard - User Name: ${currentUser?.name}');

      // Get students on campus count
      final studentsOnCampus = await provider.coreServices
          .getStudentsOnCampusCount(currentUser);

      // Get today's exit logs and calculate exits/returns
      final todayLogs = await provider.coreServices.getTodayExitLogs();

      int exits = 0;
      int returns = 0;

      for (final log in todayLogs) {
        final type = log['type'] as String?;
        if (type == 'exit') {
          exits++;
        } else if (type == 'return') {
          returns++;
        }
      }

      setState(() {
        _studentsOnCampus = studentsOnCampus;
        _todayExits = exits;
        _todayReturns = returns;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard stats: $e');
      setState(() => _isLoadingStats = false);
    }
  }

  void _onNavItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.getCurrentUser();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Control Panel',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            Text(
              'Welcome, ${user?.name ?? 'Security Officer'}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              debugPrint('Manual refresh triggered');
              final provider = Provider.of<AppProvider>(context, listen: false);
              await provider.loadUserData();
              await _loadDashboardStats();
            },
            tooltip: 'Refresh Data',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final success = await provider.logout();
              if (success && mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) => setState(() => _selectedIndex = index),
        children: [
          _buildDashboardTab(),
          const QRManagementScreen(),
          const SecurityLogsScreen(),
          _buildProfileTab(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onNavItemTapped,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code),
            label: 'QR Control',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Security Logs',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return RefreshIndicator(
      onRefresh: () async {
        final provider = Provider.of<AppProvider>(context, listen: false);
        await provider.loadUserData(); // Reload user data
        await _loadDashboardStats(); // Reload dashboard stats
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Overview Cards
            Text(
              'Today\'s Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),

            _isLoadingStats
                ? const Center(child: CircularProgressIndicator())
                : _buildOverviewCards(),

            const SizedBox(height: 32),

            // Quick Actions
            Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildQuickActions(),

            const SizedBox(height: 32),

            // Campus Status Overview
            Text(
              'Campus Status',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            _buildCampusStatusCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Exits Today',
            _todayExits.toString(),
            Icons.exit_to_app,
            Colors.orange,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Returns Today',
            _todayReturns.toString(),
            Icons.login,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'On Campus',
            _studentsOnCampus.toString(),
            Icons.people_outline,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              color.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            'Generate Exit QR',
            Icons.qr_code,
            Colors.blue,
            () => _onNavItemTapped(1),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildActionButton(
            'Scan Student QR',
            Icons.qr_code_scanner,
            Colors.purple,
            () {
              _onNavItemTapped(1);
              // TODO: Navigate directly to scanner tab in QR Management
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCampusStatusCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.security,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Campus Security Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatusRow(
              'Last Activity',
              '2 minutes ago',
              Icons.access_time,
            ),
            const SizedBox(height: 8),
            _buildStatusRow('Active Gates', '2 of 2', Icons.door_front_door),
            const SizedBox(height: 8),
            _buildStatusRow(
              'System Status',
              'Online',
              Icons.check_circle,
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(
    String label,
    String value,
    IconData icon, [
    Color? color,
  ]) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color ?? Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[600])),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? Colors.grey[800],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileTab() {
    final provider = Provider.of<AppProvider>(context);
    final user = provider.getCurrentUser();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),

          // Profile Card
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    child: Icon(
                      Icons.security,
                      size: 50,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.name ?? 'Security Officer',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Security Personnel',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey[300]),
                  const SizedBox(height: 16),

                  // Profile Info
                  _buildProfileInfoRow(
                    'Security ID',
                    user?.username ?? user?.id ?? 'SEC001',
                  ),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow(
                    'Name',
                    user?.name ?? 'Security Officer',
                  ),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Role', 'Security'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow('Shift', 'Day Shift'),
                  const SizedBox(height: 12),
                  _buildProfileInfoRow(
                    'Last Login',
                    DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now()),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Logout Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () async {
                final success = await provider.logout();
                if (success && mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: Colors.grey[600])),
        Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
