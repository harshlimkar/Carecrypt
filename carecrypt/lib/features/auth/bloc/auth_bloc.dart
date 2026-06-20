import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/notification_service.dart';
import '../models/user_model.dart';

// ─── Events ───────────────────────────────────────────────
abstract class AuthEvent extends Equatable {
  const AuthEvent();
  @override
  List<Object?> get props => [];
}

class AuthLoginRequested extends AuthEvent {
  final String email;
  final String password;
  final String role;
  const AuthLoginRequested({required this.email, required this.password, required this.role});
  @override
  List<Object?> get props => [email, password, role];
}

class AuthBiometricRequested extends AuthEvent {
  final String role;
  const AuthBiometricRequested({required this.role});
  @override
  List<Object?> get props => [role];
}

class AuthLogoutRequested extends AuthEvent {}

class AuthCheckSession extends AuthEvent {}

// ─── States ───────────────────────────────────────────────
abstract class AuthState extends Equatable {
  const AuthState();
  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}
class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final CareCryptUser user;
  const AuthAuthenticated({required this.user});
  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  const AuthError({required this.message});
  @override
  List<Object?> get props => [message];
}

// ─── BLoC ─────────────────────────────────────────────────
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final _supabase = Supabase.instance.client;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthLoginRequested>(_onLogin);
    on<AuthBiometricRequested>(_onBiometric);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSession(AuthCheckSession event, Emitter<AuthState> emit) async {
    final session = _supabase.auth.currentSession;
    if (session != null) {
      final user = await _fetchUser(session.user.id);
      if (user != null) {
        emit(AuthAuthenticated(user: user));
        return;
      }
    }
    emit(AuthUnauthenticated());
  }

  Future<void> _onLogin(AuthLoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: event.email,
        password: event.password,
      );

      if (response.user == null) {
        emit(const AuthError(message: 'Invalid credentials'));
        return;
      }

      final user = await _fetchUser(response.user!.id);
      if (user == null) {
        emit(const AuthError(message: 'User profile not found'));
        return;
      }

      // Validate role matches
      if (user.role != event.role) {
        await _supabase.auth.signOut();
        emit(AuthError(message: 'Invalid role selected. You are registered as ${user.role}.'));
        return;
      }

      // Subscribe to real-time notifications
      await NotificationService.instance.subscribeToUserNotifications(user.id);

      emit(AuthAuthenticated(user: user));
    } on AuthException catch (e) {
      emit(AuthError(message: e.message));
    } catch (e) {
      emit(AuthError(message: 'Login failed. Please try again.'));
    }
  }

  Future<void> _onBiometric(AuthBiometricRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      // Check if there's an existing session
      final session = _supabase.auth.currentSession;
      if (session == null) {
        emit(const AuthError(message: 'Please log in first to enable biometrics'));
        return;
      }
      final user = await _fetchUser(session.user.id);
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthError(message: 'Biometric login failed'));
      }
    } catch (_) {
      emit(const AuthError(message: 'Biometric authentication failed'));
    }
  }

  Future<void> _onLogout(AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await NotificationService.instance.unsubscribe();
    await _supabase.auth.signOut();
    emit(AuthUnauthenticated());
  }

  Future<CareCryptUser?> _fetchUser(String userId) async {
    try {
      final data = await _supabase
          .from('users')
          .select('*, patients(patient_id)')
          .eq('id', userId)
          .single();
      return CareCryptUser.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
