import 'package:nobox_mobile/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/filter_model.dart';
import '../models/nobox_models.dart';
import '../models/message_model.dart';
import 'dart:convert';

class FilterService {
  static const String _filterKey = 'conversation_filter';
  
  /// Save filter to SharedPreferences
  static Future<void> saveFilter(ConversationFilter filter) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterJson = json.encode(filter.toJson());
      await prefs.setString(_filterKey, filterJson);
      print('🔥 Filter saved successfully');
    } catch (e) {
      print('🔥 Error saving filter: $e');
    }
  }
  
  /// Load filter from SharedPreferences
  static Future<ConversationFilter> loadFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final filterJson = prefs.getString(_filterKey);
      
      if (filterJson != null) {
        final filterData = json.decode(filterJson) as Map<String, dynamic>;
        final filter = ConversationFilter.fromJson(filterData);
        print('🔥 Filter loaded successfully');
        return filter;
      }
    } catch (e) {
      print('🔥 Error loading filter: $e');
    }
    
    return ConversationFilter();
  }
  
  /// Clear saved filter
  static Future<void> clearFilter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_filterKey);
      print('🔥 Filter cleared successfully');
    } catch (e) {
      print('🔥 Error clearing filter: $e');
    }
  }
  
  /// Apply filter to chat links
  static List<ChatLinkModel> applyFilter(
    List<ChatLinkModel> chatLinks,
    ConversationFilter filter,
    Map<String, int> unreadCounts,
    Map<String, ChannelModel> chatChannelMap,
    List<ContactModel> contacts,
    {
      Set<String> archivedChatIds = const <String>{},
    }
  ) {
    if (!filter.hasActiveFilters) {
      // Return all non-archived chats if no filter is applied
      return chatLinks.where((chat) => !archivedChatIds.contains(chat.id)).toList();
    }
    
    return chatLinks.where((chat) {
      // Exclude archived chats
      if (archivedChatIds.contains(chat.id)) return false;
      
      // Status filter
      if (filter.selectedStatus.isNotEmpty) {
        final unreadCount = unreadCounts[chat.id] ?? 0;
        bool statusMatch = false;
        
        if (filter.selectedStatus.contains('Unassigned') && unreadCount > 0) {
          statusMatch = true;
        }
        if (filter.selectedStatus.contains('Assigned') && unreadCount == 0) {
          statusMatch = true;
        }
        if (filter.selectedStatus.contains('Resolved')) {
          statusMatch = true; // All chats are considered resolved for now
        }
        
        if (!statusMatch) return false;
      }
      
      // Mute AI Agent filter (placeholder logic)
      if (filter.selectedMuteAiAgent.isNotEmpty) {
        // This would need to be implemented based on your business logic
        // For now, we'll assume all chats are "Active"
        bool muteMatch = false;
        if (filter.selectedMuteAiAgent.contains('Active')) {
          muteMatch = true;
        }
        if (!muteMatch) return false;
      }
      
      // Channel filter
      if (filter.selectedChannels.isNotEmpty) {
        final chatChannel = chatChannelMap[chat.id];
        if (chatChannel == null) return false;
        
        bool channelMatch = false;
        for (final selectedChannel in filter.selectedChannels) {
          if (chatChannel.name.toLowerCase().contains(selectedChannel.toLowerCase()) ||
              selectedChannel.toLowerCase().contains(chatChannel.name.toLowerCase())) {
            channelMatch = true;
            break;
          }
        }
        if (!channelMatch) return false;
      }
      
      // Chat type filter
      if (filter.selectedChatTypes.isNotEmpty) {
        bool chatTypeMatch = false;
        final chatName = chat.name.toLowerCase();
        
        if (filter.selectedChatTypes.contains('Group')) {
          if (chatName.contains('group') || chatName.contains('grup') || 
              chatName.contains('orang-orang')) {
            chatTypeMatch = true;
          }
        }
        if (filter.selectedChatTypes.contains('Private')) {
          if (!chatName.contains('group') && !chatName.contains('grup') && 
              !chatName.contains('orang-orang')) {
            chatTypeMatch = true;
          }
        }
        if (!chatTypeMatch) return false;
      }
      
      // Account filter (placeholder)
      if (filter.selectedAccounts.isNotEmpty) {
        // This would need to be implemented based on your business logic
        // For now, we'll assume all chats match "Bot" account type
        bool accountMatch = filter.selectedAccounts.contains('Bot');
        if (!accountMatch) return false;
      }
      
      // Contact filter
      if (filter.selectedContacts.isNotEmpty) {
        bool contactMatch = false;
        for (final selectedContact in filter.selectedContacts) {
          if (chat.name.toLowerCase().contains(selectedContact.toLowerCase())) {
            contactMatch = true;
            break;
          }
        }
        if (!contactMatch) return false;
      }
      
      // Link filter (show all selected links)
      if (filter.selectedLinks.isNotEmpty) {
        bool linkMatch = false;
        for (final selectedLink in filter.selectedLinks) {
          if (chat.name.toLowerCase().contains(selectedLink.toLowerCase())) {
            linkMatch = true;
            break;
          }
        }
        if (!linkMatch) return false;
      }
      
      // Group filter
      if (filter.selectedGroups.isNotEmpty) {
        bool groupMatch = false;
        final chatName = chat.name.toLowerCase();
        
        // Only show if chat is a group and matches selected groups
        if (chatName.contains('group') || chatName.contains('grup') || 
            chatName.contains('orang-orang')) {
          for (final selectedGroup in filter.selectedGroups) {
            if (chat.name.toLowerCase().contains(selectedGroup.toLowerCase())) {
              groupMatch = true;
              break;
            }
          }
        }
        if (!groupMatch) return false;
      }
      
      // Human Agents filter (placeholder)
      if (filter.selectedHumanAgents.isNotEmpty) {
        // This would need to be implemented based on your business logic
        // For now, we'll assume all chats are handled by selected agents
        bool agentMatch = true;
        if (!agentMatch) return false;
      }
      
      // Campaign, Funnel, Deal, Tags filters are not implemented
      // since they show "No matches found"
      
      return true;
    }).toList();
  }
  
  /// Check if a chat matches the search query
  static bool matchesSearchQuery(
    ChatLinkModel chat, 
    String searchQuery,
    Map<String, String> lastMessageContent,
  ) {
    if (searchQuery.isEmpty) return true;
    
    final query = searchQuery.toLowerCase();
    
    // Check chat name
    if (chat.name.toLowerCase().contains(query)) return true;
    
    // Check last message content
    final lastMsg = lastMessageContent[chat.id];
    if (lastMsg != null && lastMsg.toLowerCase().contains(query)) return true;
    
    return false;
  }
  
  /// Get filter summary text
  static String getFilterSummary(ConversationFilter filter) {
    if (!filter.hasActiveFilters) return '';
    
    final List<String> activeSummary = [];
    
    if (filter.selectedStatus.isNotEmpty) {
      activeSummary.add('Status: ${filter.selectedStatus.join(', ')}');
    }
    
    if (filter.selectedChannels.isNotEmpty) {
      activeSummary.add('Channel: ${filter.selectedChannels.join(', ')}');
    }
    
    if (filter.selectedChatTypes.isNotEmpty) {
      activeSummary.add('Type: ${filter.selectedChatTypes.join(', ')}');
    }
    
    if (filter.selectedContacts.isNotEmpty) {
      activeSummary.add('Contacts: ${filter.selectedContacts.length} selected');
    }
    
    if (filter.selectedHumanAgents.isNotEmpty) {
      activeSummary.add('Agents: ${filter.selectedHumanAgents.join(', ')}');
    }
    
    return activeSummary.join(' • ');
  }
}