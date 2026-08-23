import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/branch.dart';
import 'services_provider.dart';

final branchesProvider = StreamProvider<List<Branch>>((ref) {
  return ref.watch(firestoreServiceProvider).getBranches();
});
