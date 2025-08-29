import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:flutter/foundation.dart';
import 'app_state.dart';
import 'reducer.dart';

/// Create and configure the Redux store
Store<AppState> createStore() {
  debugPrint('🏪 [Store] Creating Redux store...');
  
  // Initial state
  const initialState = AppState();
  
  // Create store with thunk middleware for async actions
  final store = Store<AppState>(
    appReducer,
    initialState: initialState,
    middleware: [
      thunkMiddleware,
      // Add logging middleware for debugging
      _loggingMiddleware,
    ],
  );
  
  debugPrint('✅ [Store] Redux store created successfully');
  return store;
}

/// Logging middleware for debugging Redux actions
void _loggingMiddleware(Store<AppState> store, dynamic action, NextDispatcher next) {
  debugPrint('🔄 [Redux] Action: ${action.runtimeType}');
  debugPrint('📊 [Redux] Current state: ${store.state}');
  
  // Call the next middleware or reducer
  next(action);
  
  debugPrint('📊 [Redux] New state: ${store.state}');
  debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
} 