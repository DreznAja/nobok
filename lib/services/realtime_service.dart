import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../models/message_model.dart';
import '../services/user_service.dart';
import '../utils/connection_utils.dart';

/// Enhanced real-time service for NoBox Chat with SignalR-like functionality
class RealTimeService {
  static const String _hubUrl = 'wss://id.nobox.ai/messagehub';
  static const Duration _reconnectDelay = Duration(seconds: 15);
  static const Duration _heartbeatInterval = Duration(seconds: 30);
  static const int _maxReconnectAttempts = 5;
  
  static WebSocketChannel? _channel;
  static StreamSubscription? _subscription;
  static Timer? _heartbeatTimer;
  static Timer? _reconnectTimer;
  
  static bool _isConnected = false;
  static bool _isReconnecting = false;
  static int _reconnectAttempts = 0;
  static String? _currentRoomId;
  static List<String> _subscribedRooms = [];
  
  // Event controllers
  static final StreamController<NoboxMessage> _messageController = 
      StreamController<NoboxMessage>.broadcast();
  static final StreamController<Map<String, dynamic>> _roomUpdateController = 
      StreamController<Map<String, dynamic>>.broadcast();
  static final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
  static final StreamController<Map<String, dynamic>> _ackController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  // Pending messages queue
  static final List<Map<String, dynamic>> _pendingMessages = [];
  
  /// Initialize real-time service
  static Future<void> initialize() async {
    try {
      print('🔥 📡 Initializing RealTimeService...');
      await _connect();
    } catch (e) {
      print('🔥 Error initializing RealTimeService: $e');
      _scheduleReconnect();
    }
  }
  
  /// Connect to WebSocket
  static Future<void> _connect() async {
    try {
      if (_isConnected || _isReconnecting) return;
      
      _isReconnecting = true;
      print('🔥 📡 Connecting to WebSocket: $_hubUrl');
      
      // Create WebSocket connection
      _channel = WebSocketChannel.connect(
        Uri.parse(_hubUrl),
        protocols: ['signalr'],
      );
      
      // Listen to messages
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
      );
      
      // Send handshake
      await _sendHandshake();
      
      // Start heartbeat
      _startHeartbeat();
      
      _isConnected = true;
      _isReconnecting = false;
      _reconnectAttempts = 0;
      
      _connectionController.add(true);
      print('🔥 📡 ✅ WebSocket connected successfully');
      
      // Subscribe user
      await _subscribeUser();
      
      // Process pending messages
      await _processPendingMessages();
      
    } catch (e) {
      print('🔥 📡 ❌ WebSocket connection failed: $e');
      _isReconnecting = false;
      _scheduleReconnect();
    }
  }
  
  /// Send handshake message
  static Future<void> _sendHandshake() async {
    final handshake = {
      'protocol': 'json',
      'version': 1,
    };
    
    await _sendMessage(jsonEncode(handshake) + '\x1e');
  }
  
  /// Subscribe current user
  static Future<void> _subscribeUser() async {
    try {
      final currentUser = UserService.currentUserId;
      if (currentUser == null) return;
      
      // Subscribe based on user role
      if (UserService.isLoggedIn) {
        await _invokeHubMethod('SubscribeUserAgent', [currentUser]);
        print('🔥 📡 Subscribed as Agent: $currentUser');
      }
    } catch (e) {
      print('🔥 Error subscribing user: $e');
    }
  }
  
  /// Join conversation room
  static Future<void> joinConversation(String roomId) async {
    try {
      if (_currentRoomId == roomId) return;
      
      // Leave current room if any
      if (_currentRoomId != null) {
        await _invokeHubMethod('LeaveConversation', [_currentRoomId]);
      }
      
      // Join new room
      await _invokeHubMethod('JoinConversation', [roomId, _currentRoomId ?? '']);
      
      _currentRoomId = roomId;
      
      if (!_subscribedRooms.contains('Notifikasi$roomId')) {
        _subscribedRooms.add('Notifikasi$roomId');
        await _invokeHubMethod('Subscribe', [['Notifikasi$roomId']]);
      }
      
      print('🔥 📡 Joined conversation: $roomId');
    } catch (e) {
      print('🔥 Error joining conversation: $e');
    }
  }
  
  /// Leave conversation room
  static Future<void> leaveConversation() async {
    try {
      if (_currentRoomId != null) {
        await _invokeHubMethod('LeaveConversation', [_currentRoomId]);
        _subscribedRooms.removeWhere((room) => room.contains(_currentRoomId!));
        _currentRoomId = null;
        print('🔥 📡 Left conversation');
      }
    } catch (e) {
      print('🔥 Error leaving conversation: $e');
    }
  }
  
  /// Send message through SignalR
  static Future<void> sendMessage(Map<String, dynamic> messageData) async {
    try {
      if (!_isConnected) {
        _pendingMessages.add(messageData);
        print('🔥 📡 Message queued (offline): ${messageData['Msg']['Msg']}');
        return;
      }
      
      await _invokeHubMethod('KirimPesan', [jsonEncode(messageData)]);
      print('🔥 📡 Message sent via SignalR');
    } catch (e) {
      print('🔥 Error sending message via SignalR: $e');
      _pendingMessages.add(messageData);
    }
  }
  
  /// Mark message as read
  static Future<void> markAsRead(String roomId) async {
    try {
      await _invokeHubMethod('ReadMsgCount', [roomId]);
    } catch (e) {
      print('🔥 Error marking as read: $e');
    }
  }
  
  /// Handle incoming WebSocket messages
  static void _handleMessage(dynamic data) {
    try {
      if (data is String) {
        // Handle different message types
        if (data.contains('"type":1')) {
          // Hub method invocation result
          _handleHubMethodResult(data);
        } else if (data.contains('"type":2')) {
          // Hub method invocation
          _handleHubMethodInvocation(data);
        } else if (data.contains('TerimaPesan')) {
          // New message received
          _handleNewMessage(data);
        } else if (data.contains('TerimaAck')) {
          // Message acknowledgment
          _handleMessageAck(data);
        } else if (data.contains('TerimaSubSpv') || data.contains('TerimaSubAgent')) {
          // Room update
          _handleRoomUpdate(data);
        }
      }
    } catch (e) {
      print('🔥 📡 Error handling message: $e');
    }
  }
  
  /// Handle hub method results
  static void _handleHubMethodResult(String data) {
    try {
      final parsed = jsonDecode(data);
      print('🔥 📡 Hub method result: ${parsed['result']}');
    } catch (e) {
      print('🔥 Error parsing hub method result: $e');
    }
  }
  
  /// Handle hub method invocations
  static void _handleHubMethodInvocation(String data) {
    try {
      final parsed = jsonDecode(data);
      final target = parsed['target'];
      final arguments = parsed['arguments'] as List<dynamic>?;
      
      switch (target) {
        case 'TerimaPesan':
          if (arguments != null && arguments.length >= 2) {
            _handleNewMessage(arguments[0], arguments[1]);
          }
          break;
        case 'TerimaAck':
          if (arguments != null && arguments.length >= 3) {
            _handleMessageAck(arguments[0], arguments[1], arguments[2]);
          }
          break;
        case 'TerimaSubSpv':
        case 'TerimaSubAgent':
          if (arguments != null && arguments.length >= 2) {
            _handleRoomUpdate(arguments[0], arguments[1]);
          }
          break;
      }
    } catch (e) {
      print('🔥 Error handling hub method invocation: $e');
    }
  }
  
  /// Handle new message
  static void _handleNewMessage(dynamic room, dynamic messageData) {
    try {
      if (room.toString().contains(_currentRoomId ?? '')) {
        final messageJson = jsonDecode(messageData.toString());
        final message = NoboxMessage.fromDetailRoomJson(messageJson);
        
        _messageController.add(message);
        print('🔥 📡 ✅ New message received: ${message.content}');
      }
    } catch (e) {
      print('🔥 Error handling new message: $e');
    }
  }
  
  /// Handle message acknowledgment
  static void _handleMessageAck(dynamic roomId, dynamic messageId, dynamic status) {
    try {
      _ackController.add({
        'roomId': roomId.toString(),
        'messageId': messageId.toString(),
        'status': status,
      });
      print('🔥 📡 Message ack: $messageId -> $status');
    } catch (e) {
      print('🔥 Error handling message ack: $e');
    }
  }
  
  /// Handle room updates
  static void _handleRoomUpdate(dynamic room, dynamic updateData) {
    try {
      final updateJson = jsonDecode(updateData.toString());
      _roomUpdateController.add({
        'room': room.toString(),
        'data': updateJson,
      });
      print('🔥 📡 Room update received');
    } catch (e) {
      print('🔥 Error handling room update: $e');
    }
  }
  
  /// Invoke hub method
  static Future<void> _invokeHubMethod(String methodName, List<dynamic> arguments) async {
    if (!_isConnected || _channel == null) {
      throw Exception('WebSocket not connected');
    }
    
    final invocation = {
      'type': 1,
      'target': methodName,
      'arguments': arguments,
    };
    
    await _sendMessage(jsonEncode(invocation) + '\x1e');
  }
  
  /// Send raw message
  static Future<void> _sendMessage(String message) async {
    if (_channel != null) {
      _channel!.sink.add(message);
    }
  }
  
  /// Start heartbeat
  static void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_isConnected) {
        _sendHeartbeat();
      }
    });
  }
  
  /// Send heartbeat
  static void _sendHeartbeat() {
    try {
      final ping = {'type': 6};
      _sendMessage(jsonEncode(ping) + '\x1e');
    } catch (e) {
      print('🔥 Error sending heartbeat: $e');
    }
  }
  
  /// Handle WebSocket errors
  static void _handleError(dynamic error) {
    print('🔥 📡 WebSocket error: $error');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }
  
  /// Handle WebSocket disconnection
  static void _handleDisconnection() {
    print('🔥 📡 WebSocket disconnected');
    _isConnected = false;
    _connectionController.add(false);
    _scheduleReconnect();
  }
  
  /// Schedule reconnection
  static void _scheduleReconnect() {
    if (_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts) return;
    
    _reconnectAttempts++;
    print('🔥 📡 Scheduling reconnect attempt $_reconnectAttempts/$_maxReconnectAttempts');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      _connect();
    });
  }
  
  /// Process pending messages
  static Future<void> _processPendingMessages() async {
    if (_pendingMessages.isEmpty) return;
    
    print('🔥 📡 Processing ${_pendingMessages.length} pending messages...');
    
    final messagesToProcess = List<Map<String, dynamic>>.from(_pendingMessages);
    _pendingMessages.clear();
    
    for (final message in messagesToProcess) {
      try {
        await sendMessage(message);
        await Future.delayed(const Duration(milliseconds: 500)); // Rate limiting
      } catch (e) {
        print('🔥 Error processing pending message: $e');
        _pendingMessages.add(message); // Re-queue failed message
      }
    }
  }
  
  /// Get message stream
  static Stream<NoboxMessage> get messageStream => _messageController.stream;
  
  /// Get room update stream
  static Stream<Map<String, dynamic>> get roomUpdateStream => _roomUpdateController.stream;
  
  /// Get connection stream
  static Stream<bool> get connectionStream => _connectionController.stream;
  
  /// Get acknowledgment stream
  static Stream<Map<String, dynamic>> get ackStream => _ackController.stream;
  
  /// Check if connected
  static bool get isConnected => _isConnected;
  
  /// Get current room ID
  static String? get currentRoomId => _currentRoomId;
  
  /// Get pending messages count
  static int get pendingMessagesCount => _pendingMessages.length;
  
  /// Force reconnect
  static Future<void> forceReconnect() async {
    print('🔥 📡 Force reconnecting...');
    await disconnect();
    _reconnectAttempts = 0;
    await _connect();
  }
  
  /// Disconnect
  static Future<void> disconnect() async {
    try {
      _isConnected = false;
      _isReconnecting = false;
      
      _heartbeatTimer?.cancel();
      _reconnectTimer?.cancel();
      
      await _subscription?.cancel();
      await _channel?.sink.close(status.normalClosure);
      
      _channel = null;
      _subscription = null;
      _currentRoomId = null;
      _subscribedRooms.clear();
      
      _connectionController.add(false);
      print('🔥 📡 Disconnected from WebSocket');
    } catch (e) {
      print('🔥 Error disconnecting: $e');
    }
  }
  
  /// Dispose service
  static Future<void> dispose() async {
    await disconnect();
    
    await _messageController.close();
    await _roomUpdateController.close();
    await _connectionController.close();
    await _ackController.close();
    
    print('🔥 📡 RealTimeService disposed');
  }
  
  /// Get connection status
  static Map<String, dynamic> getStatus() {
    return {
      'isConnected': _isConnected,
      'isReconnecting': _isReconnecting,
      'reconnectAttempts': _reconnectAttempts,
      'currentRoom': _currentRoomId,
      'subscribedRooms': _subscribedRooms.length,
      'pendingMessages': _pendingMessages.length,
    };
  }
  
  /// Archive conversation via SignalR
  static Future<void> archiveConversation(String roomId) async {
    try {
      await _invokeHubMethod('MoveArchive', [roomId]);
    } catch (e) {
      print('🔥 Error archiving conversation via SignalR: $e');
    }
  }
  
  /// Mark conversation as resolved via SignalR
  static Future<void> markAsResolved(String roomId) async {
    try {
      await _invokeHubMethod('MarkResolved', [roomId]);
    } catch (e) {
      print('🔥 Error marking as resolved via SignalR: $e');
    }
  }
  
  /// Mute/unmute bot via SignalR
  static Future<void> muteBot({
    required String roomId,
    required String accountId,
    required String linkIdExt,
    required String linkId,
    required bool mute,
  }) async {
    try {
      final method = mute ? 'MuteBot' : 'UnmuteBot';
      await _invokeHubMethod(method, [roomId, accountId, linkIdExt, linkId]);
    } catch (e) {
      print('🔥 Error ${mute ? 'muting' : 'unmuting'} bot via SignalR: $e');
    }
  }
  
  /// Set need reply via SignalR
  static Future<void> setNeedReply(String roomId, bool needReply) async {
    try {
      await _invokeHubMethod('MkNeedReply', [roomId, needReply ? 1 : 0]);
    } catch (e) {
      print('🔥 Error setting need reply via SignalR: $e');
    }
  }
  
  /// Pin/unpin conversation via SignalR
  static Future<void> pinConversation(String roomId, bool pin) async {
    try {
      await _invokeHubMethod('RoomPinUnpin', [roomId, pin ? 2 : 1]);
    } catch (e) {
      print('🔥 Error ${pin ? 'pinning' : 'unpinning'} conversation via SignalR: $e');
    }
  }
  
  /// Delete message via SignalR
  static Future<void> deleteMessage(String roomId, String messageId) async {
    try {
      await _invokeHubMethod('DelMsg', [roomId, int.parse(messageId)]);
    } catch (e) {
      print('🔥 Error deleting message via SignalR: $e');
    }
  }
  
  /// Add agent to conversation via SignalR
  static Future<void> addAgent({
    required String roomId,
    required String userId,
    required String displayName,
    String? userImage,
  }) async {
    try {
      final agentData = {
        'RoomId': roomId,
        'UserId': userId,
        'DisplayName': displayName,
        'UserImage': userImage,
        'HandId': UserService.currentUserId,
      };
      
      await _invokeHubMethod('MkAgent', [roomId, jsonEncode({
        'Mode': 'Add',
        'Data': agentData,
      })]);
    } catch (e) {
      print('🔥 Error adding agent via SignalR: $e');
    }
  }
  
  /// Remove agent from conversation via SignalR
  static Future<void> removeAgent(String roomId, String agentId) async {
    try {
      await _invokeHubMethod('MkAgent', [roomId, jsonEncode({
        'Mode': 'Delete',
        'Data': agentId,
      })]);
    } catch (e) {
      print('🔥 Error removing agent via SignalR: $e');
    }
  }
  
  /// Add note via SignalR
  static Future<void> addNote(String roomId, String noteContent) async {
    try {
      final noteData = {
        'Mode': 'Add',
        'Cnt': noteContent,
        'RoomId': roomId,
      };
      
      await _invokeHubMethod('MkNote', [roomId, jsonEncode(noteData)]);
    } catch (e) {
      print('🔥 Error adding note via SignalR: $e');
    }
  }
  
  /// Update tags via SignalR
  static Future<void> updateTags(String roomId, List<String> tagIds) async {
    try {
      final tagData = {
        'Mode': 'Select',
        'Id': tagIds,
      };
      
      await _invokeHubMethod('MkTag', [roomId, jsonEncode(tagData), jsonEncode(tagIds)]);
    } catch (e) {
      print('🔥 Error updating tags via SignalR: $e');
    }
  }
  
  /// Update funnel via SignalR
  static Future<void> updateFunnel(String roomId, String? funnelId) async {
    try {
      final funnelData = {
        'Mode': 'Select',
        'Id': funnelId,
      };
      
      await _invokeHubMethod('MkFunnel', [roomId, jsonEncode(funnelData)]);
    } catch (e) {
      print('🔥 Error updating funnel via SignalR: $e');
    }
  }
  
  /// Block/unblock contact via SignalR
  static Future<void> blockContact({
    required String roomId,
    required String contactId,
    required int status,
    required bool block,
  }) async {
    try {
      await _invokeHubMethod('ContactBlockUnblock', [roomId, status, contactId, block ? 1 : 0]);
    } catch (e) {
      print('🔥 Error ${block ? 'blocking' : 'unblocking'} contact via SignalR: $e');
    }
  }
  
  /// Create new conversation via SignalR
  static Future<Map<String, dynamic>?> createNewConversation(Map<String, dynamic> conversationData) async {
    try {
      // This would need to be implemented based on your SignalR hub methods
      await _invokeHubMethod('CreateNewRoom', [conversationData]);
      
      // Return success indicator
      return {'success': true};
    } catch (e) {
      print('🔥 Error creating new conversation via SignalR: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  /// Get real-time statistics
  static Map<String, dynamic> getStatistics() {
    return {
      'isConnected': _isConnected,
      'reconnectAttempts': _reconnectAttempts,
      'subscribedRooms': _subscribedRooms.length,
      'pendingMessages': _pendingMessages.length,
      'currentRoom': _currentRoomId,
      'uptime': _isConnected ? 'Connected' : 'Disconnected',
    };
  }
}