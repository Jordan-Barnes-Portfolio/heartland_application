import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HoursTrackerPage extends StatefulWidget {
  const HoursTrackerPage({Key? key}) : super(key: key);

  @override
  _HoursTrackerPageState createState() => _HoursTrackerPageState();
}

class _HoursTrackerPageState extends State<HoursTrackerPage> {
  bool isClockedIn = false;
  String currentDocId = '';
  DateTime? startTime;
  String? selectedEmployee;
  bool isLoading = false;

  // List of employees
  final List<String> employees = ['Joshua', 'Jordan', 'Kaleb', 'Chase'];

  // Reference to Firestore collection
  final CollectionReference workMetrics =
      FirebaseFirestore.instance.collection('workMetrics');

  @override
  void initState() {
    super.initState();
    // Check for any active sessions on app start
    checkActiveSession();
  }

  Future<void> checkActiveSession() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Check for any active sessions for all employees
      final activeSessionQuery =
          await workMetrics.where('status', isEqualTo: 'active').get();

      if (activeSessionQuery.docs.isNotEmpty) {
        final activeSession = activeSessionQuery.docs.first;
        final activeEmployee = activeSession.get('employeeName') as String;

        setState(() {
          selectedEmployee = activeEmployee;
          isClockedIn = true;
          currentDocId = activeSession.id;
          startTime = (activeSession.get('startTime') as Timestamp).toDate();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking active sessions: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> checkEmployeeStatus(String employeeName) async {
    setState(() {
      isLoading = true;
    });

    try {
      final activeSessionQuery = await workMetrics
          .where('employeeName', isEqualTo: employeeName)
          .where('status', isEqualTo: 'active')
          .get();

      setState(() {
        if (activeSessionQuery.docs.isNotEmpty) {
          final activeSession = activeSessionQuery.docs.first;
          isClockedIn = true;
          currentDocId = activeSession.id;
          startTime = (activeSession.get('startTime') as Timestamp).toDate();
        } else {
          isClockedIn = false;
          currentDocId = '';
          startTime = null;
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking employee status: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleClockInOut() async {
    if (selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee first')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    final now = DateTime.now();

    if (!isClockedIn) {
      // Clock In logic
      try {
        // Double check no active session exists
        final activeSessionQuery = await workMetrics
            .where('employeeName', isEqualTo: selectedEmployee)
            .where('status', isEqualTo: 'active')
            .get();

        if (activeSessionQuery.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee is already clocked in')),
          );
          return;
        }

        DocumentReference docRef = await workMetrics.add({
          'employeeName': selectedEmployee,
          'startTime': now,
          'status': 'active',
          'createdAt': now,
        });

        setState(() {
          isClockedIn = true;
          currentDocId = docRef.id;
          startTime = now;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clocking in: $e')),
        );
      }
    } else {
      // Clock Out logic
      try {
        if (startTime != null) {
          final Duration difference = now.difference(startTime!);
          final double hours = difference.inMinutes / 60.0;

          await workMetrics.doc(currentDocId).update({
            'endTime': now,
            'status': 'completed',
            'hours': double.parse(hours.toStringAsFixed(2)),
            'updatedAt': now,
          });

          setState(() {
            isClockedIn = false;
            currentDocId = '';
            startTime = null;
          });
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error clocking out: $e')),
        );
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Hours Tracker',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.blueGrey[800],
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey[800]!, Colors.blueGrey[600]!],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.punch_clock_rounded,
                  size: 100,
                  color: Colors.white,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Employee Time Tracking',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 36),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Employee Selection Dropdown
                        DropdownButtonFormField<String>(
                          value: selectedEmployee,
                          decoration: InputDecoration(
                            labelText: 'Select Employee',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          items: employees.map((String employee) {
                            return DropdownMenuItem<String>(
                              value: employee,
                              child: Text(employee),
                            );
                          }).toList(),
                          onChanged: isLoading
                              ? null
                              : (String? newValue) {
                                  setState(() {
                                    selectedEmployee = newValue;
                                  });
                                  if (newValue != null) {
                                    checkEmployeeStatus(newValue);
                                  }
                                },
                        ),
                        const SizedBox(height: 24),
                        if (selectedEmployee != null) ...[
                          Text(
                            isClockedIn
                                ? 'Currently Working'
                                : 'Not Clocked In',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (startTime != null) ...[
                          Text(
                            'Started at: ${startTime!.toLocal().toString().split('.')[0]}',
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                        ],
                        if (selectedEmployee != null) ...[
                          if (isLoading)
                            const Center(
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                              ),
                            )
                          else
                            ElevatedButton.icon(
                              icon: Icon(
                                isClockedIn ? Icons.logout : Icons.login,
                                color: Colors.white,
                              ),
                              label: Text(
                                isClockedIn ? 'Clock Out' : 'Clock In',
                                style: const TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    isClockedIn ? Colors.red : Colors.orange,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
                                ),
                              ),
                              onPressed: isLoading ? null : handleClockInOut,
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
