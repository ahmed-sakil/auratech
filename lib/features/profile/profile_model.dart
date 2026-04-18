import 'package:equatable/equatable.dart';

import '../../core/constants/app_enums.dart';

class ProfileModel extends Equatable {
  final String id;
  final String email;
  final String fullName;
  final AppRole role;
  final ProfileStatus status;

  const ProfileModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    required this.status,
  });

  factory ProfileModel.fromMap(Map<String, dynamic> map) {
    return ProfileModel(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      fullName: (map['full_name'] as String?) ?? '',
      role: _roleFromString((map['role'] as String?) ?? 'buyer'),
      status: _statusFromString((map['status'] as String?) ?? 'active'),
    );
  }

  @override
  List<Object?> get props => [id, email, fullName, role, status];
}

AppRole _roleFromString(String value) {
  switch (value) {
    case 'buyer':
      return AppRole.buyer;
    case 'seller':
      return AppRole.seller;
    case 'admin':
      return AppRole.admin;
    default:
      return AppRole.buyer;
  }
}

ProfileStatus _statusFromString(String value) {
  switch (value) {
    case 'active':
      return ProfileStatus.active;
    case 'pending':
      return ProfileStatus.pending;
    case 'rejected':
      return ProfileStatus.rejected;
    case 'banned':
      return ProfileStatus.banned;
    default:
      return ProfileStatus.active;
  }
}