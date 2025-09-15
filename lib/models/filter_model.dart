import 'package:nobox_mobile/services/api_service.dart';

/// Model untuk menyimpan state filter conversation
class ConversationFilter {
  // Status filter
  Set<String> selectedStatus;
  
  // Is Mute AI Agent filter
  Set<String> selectedMuteAiAgent;
  
  // Channel filter
  Set<String> selectedChannels;
  
  // Chat type filter
  Set<String> selectedChatTypes;
  
  // Account filter
  Set<String> selectedAccounts;
  
  // Contact filter
  Set<String> selectedContacts;
  
  // Link filter
  Set<String> selectedLinks;
  
  // Group filter
  Set<String> selectedGroups;
  
  // Campaign filter (always empty for now)
  Set<String> selectedCampaigns;
  
  // Funnel filter (always empty for now)
  Set<String> selectedFunnels;
  
  // Deal filter (always empty for now)
  Set<String> selectedDeals;
  
  // Tags filter (always empty for now)
  Set<String> selectedTags;
  
  // Human Agents filter
  Set<String> selectedHumanAgents;

  ConversationFilter({
    Set<String>? selectedStatus,
    Set<String>? selectedMuteAiAgent,
    Set<String>? selectedChannels,
    Set<String>? selectedChatTypes,
    Set<String>? selectedAccounts,
    Set<String>? selectedContacts,
    Set<String>? selectedLinks,
    Set<String>? selectedGroups,
    Set<String>? selectedCampaigns,
    Set<String>? selectedFunnels,
    Set<String>? selectedDeals,
    Set<String>? selectedTags,
    Set<String>? selectedHumanAgents,
  }) : selectedStatus = selectedStatus ?? <String>{},
       selectedMuteAiAgent = selectedMuteAiAgent ?? <String>{},
       selectedChannels = selectedChannels ?? <String>{},
       selectedChatTypes = selectedChatTypes ?? <String>{},
       selectedAccounts = selectedAccounts ?? <String>{},
       selectedContacts = selectedContacts ?? <String>{},
       selectedLinks = selectedLinks ?? <String>{},
       selectedGroups = selectedGroups ?? <String>{},
       selectedCampaigns = selectedCampaigns ?? <String>{},
       selectedFunnels = selectedFunnels ?? <String>{},
       selectedDeals = selectedDeals ?? <String>{},
       selectedTags = selectedTags ?? <String>{},
       selectedHumanAgents = selectedHumanAgents ?? <String>{};

  /// Check if any filter is applied
  bool get hasActiveFilters {
    return selectedStatus.isNotEmpty ||
           selectedMuteAiAgent.isNotEmpty ||
           selectedChannels.isNotEmpty ||
           selectedChatTypes.isNotEmpty ||
           selectedAccounts.isNotEmpty ||
           selectedContacts.isNotEmpty ||
           selectedLinks.isNotEmpty ||
           selectedGroups.isNotEmpty ||
           selectedCampaigns.isNotEmpty ||
           selectedFunnels.isNotEmpty ||
           selectedDeals.isNotEmpty ||
           selectedTags.isNotEmpty ||
           selectedHumanAgents.isNotEmpty;
  }

  /// Get total number of active filters
  int get activeFilterCount {
    int count = 0;
    if (selectedStatus.isNotEmpty) count++;
    if (selectedMuteAiAgent.isNotEmpty) count++;
    if (selectedChannels.isNotEmpty) count++;
    if (selectedChatTypes.isNotEmpty) count++;
    if (selectedAccounts.isNotEmpty) count++;
    if (selectedContacts.isNotEmpty) count++;
    if (selectedLinks.isNotEmpty) count++;
    if (selectedGroups.isNotEmpty) count++;
    if (selectedCampaigns.isNotEmpty) count++;
    if (selectedFunnels.isNotEmpty) count++;
    if (selectedDeals.isNotEmpty) count++;
    if (selectedTags.isNotEmpty) count++;
    if (selectedHumanAgents.isNotEmpty) count++;
    return count;
  }

  /// Reset all filters
  ConversationFilter reset() {
    return ConversationFilter();
  }

  /// Copy with new values
  ConversationFilter copyWith({
    Set<String>? selectedStatus,
    Set<String>? selectedMuteAiAgent,
    Set<String>? selectedChannels,
    Set<String>? selectedChatTypes,
    Set<String>? selectedAccounts,
    Set<String>? selectedContacts,
    Set<String>? selectedLinks,
    Set<String>? selectedGroups,
    Set<String>? selectedCampaigns,
    Set<String>? selectedFunnels,
    Set<String>? selectedDeals,
    Set<String>? selectedTags,
    Set<String>? selectedHumanAgents,
  }) {
    return ConversationFilter(
      selectedStatus: selectedStatus ?? Set<String>.from(this.selectedStatus),
      selectedMuteAiAgent: selectedMuteAiAgent ?? Set<String>.from(this.selectedMuteAiAgent),
      selectedChannels: selectedChannels ?? Set<String>.from(this.selectedChannels),
      selectedChatTypes: selectedChatTypes ?? Set<String>.from(this.selectedChatTypes),
      selectedAccounts: selectedAccounts ?? Set<String>.from(this.selectedAccounts),
      selectedContacts: selectedContacts ?? Set<String>.from(this.selectedContacts),
      selectedLinks: selectedLinks ?? Set<String>.from(this.selectedLinks),
      selectedGroups: selectedGroups ?? Set<String>.from(this.selectedGroups),
      selectedCampaigns: selectedCampaigns ?? Set<String>.from(this.selectedCampaigns),
      selectedFunnels: selectedFunnels ?? Set<String>.from(this.selectedFunnels),
      selectedDeals: selectedDeals ?? Set<String>.from(this.selectedDeals),
      selectedTags: selectedTags ?? Set<String>.from(this.selectedTags),
      selectedHumanAgents: selectedHumanAgents ?? Set<String>.from(this.selectedHumanAgents),
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'selectedStatus': selectedStatus.toList(),
      'selectedMuteAiAgent': selectedMuteAiAgent.toList(),
      'selectedChannels': selectedChannels.toList(),
      'selectedChatTypes': selectedChatTypes.toList(),
      'selectedAccounts': selectedAccounts.toList(),
      'selectedContacts': selectedContacts.toList(),
      'selectedLinks': selectedLinks.toList(),
      'selectedGroups': selectedGroups.toList(),
      'selectedCampaigns': selectedCampaigns.toList(),
      'selectedFunnels': selectedFunnels.toList(),
      'selectedDeals': selectedDeals.toList(),
      'selectedTags': selectedTags.toList(),
      'selectedHumanAgents': selectedHumanAgents.toList(),
    };
  }

  /// Create from JSON
  factory ConversationFilter.fromJson(Map<String, dynamic> json) {
    return ConversationFilter(
      selectedStatus: Set<String>.from(json['selectedStatus'] ?? []),
      selectedMuteAiAgent: Set<String>.from(json['selectedMuteAiAgent'] ?? []),
      selectedChannels: Set<String>.from(json['selectedChannels'] ?? []),
      selectedChatTypes: Set<String>.from(json['selectedChatTypes'] ?? []),
      selectedAccounts: Set<String>.from(json['selectedAccounts'] ?? []),
      selectedContacts: Set<String>.from(json['selectedContacts'] ?? []),
      selectedLinks: Set<String>.from(json['selectedLinks'] ?? []),
      selectedGroups: Set<String>.from(json['selectedGroups'] ?? []),
      selectedCampaigns: Set<String>.from(json['selectedCampaigns'] ?? []),
      selectedFunnels: Set<String>.from(json['selectedFunnels'] ?? []),
      selectedDeals: Set<String>.from(json['selectedDeals'] ?? []),
      selectedTags: Set<String>.from(json['selectedTags'] ?? []),
      selectedHumanAgents: Set<String>.from(json['selectedHumanAgents'] ?? []),
    );
  }

  @override
  String toString() {
    return 'ConversationFilter(activeFilters: $activeFilterCount)';
  }
}

/// Static filter options
class FilterOptions {
  static const List<String> statusOptions = [
    'Unassigned',
    'Assigned', 
    'Resolved'
  ];

  static const List<String> muteAiAgentOptions = [
    'Active',
    'Inactive'
  ];

  static const List<String> channelOptions = [
    'Mobile Number',
    'NoboxChat',
    'Telegram',
    'Tokopedia.com',
    'WhatsApp'
  ];

  static const List<String> chatTypeOptions = [
    'Private',
    'Group'
  ];

  // ✅ UPDATED: Account options untuk match dengan New Conversation
  static const List<String> accountOptions = [
    'Bot'
  ];

  static const List<String> humanAgentOptions = [
    'Danz Dani',
    'Zaalan Coding'
  ];

  // Dynamic options that will be populated from API data
  static List<String> getContactOptions(List<ContactModel> contacts) {
    return contacts.map((contact) => contact.name).toList();
  }

  static List<String> getLinkOptions(List<ChatLinkModel> links) {
    return links.map((link) => link.name).toList();
  }

  static List<String> getGroupOptions(List<ChatLinkModel> links) {
    return links
        .where((link) => link.name.toLowerCase().contains('group') || 
                        link.name.toLowerCase().contains('grup'))
        .map((link) => link.name)
        .toList();
  }
}