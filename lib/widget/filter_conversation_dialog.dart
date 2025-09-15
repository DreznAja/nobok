import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nobox_mobile/services/api_service.dart';
import '../models/api_response.dart';
import '../models/nobox_models.dart';
import '../models/filter_model.dart';

class FilterConversationDialog extends StatefulWidget {
  final ConversationFilter currentFilter;
  final List<ChannelModel> channels;
  final List<AccountModel> accounts;
  final List<ContactModel> contacts;
  final List<ChatLinkModel> chatLinks;
  final Function(ConversationFilter) onApplyFilter;

  const FilterConversationDialog({
    Key? key,
    required this.currentFilter,
    required this.channels,
    required this.accounts,
    required this.contacts,
    required this.chatLinks,
    required this.onApplyFilter,
  }) : super(key: key);

  @override
  State<FilterConversationDialog> createState() => _FilterConversationDialogState();
}

class _FilterConversationDialogState extends State<FilterConversationDialog> {
  late ConversationFilter _tempFilter;
  
  // Colors matching the main app design
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  @override
  void initState() {
    super.initState();
    _tempFilter = widget.currentFilter.copyWith();
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
    bool enabled = true,
    bool showNoMatches = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            borderRadius: BorderRadius.circular(6),
            color: enabled ? Colors.white : const Color(0xFFFAFAFA),
          ),
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            underline: const SizedBox(),
            hint: const Text(
              '--select--',
              style: TextStyle(
                fontSize: 14,
                color: textSecondary,
                fontFamily: 'Poppins',
              ),
            ),
            style: const TextStyle(
              fontSize: 14,
              color: textPrimary,
              fontFamily: 'Poppins',
            ),
            items: items.isEmpty && showNoMatches
                ? [
                    DropdownMenuItem<T>(
                      value: null,
                      enabled: false,
                      child: Text(
                        'No matches found',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                  ]
                : items.map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(itemBuilder(item)),
                  )).toList(),
            onChanged: (items.isEmpty && showNoMatches) ? null : (enabled ? onChanged : null),
          ),
        ),
      ],
    );
  }

  // Add these state variables for single selections
  String? _selectedStatus;
  String? _selectedMuteAiAgent;
  String? _selectedReadStatus;
  String? _selectedChannel;
  String? _selectedChatType;
  String? _selectedAccount;
  String? _selectedContact;
  String? _selectedLink;
  String? _selectedGroup;
  String? _selectedCampaign;
  String? _selectedFunnel;
  String? _selectedDeal;
  String? _selectedTags;
  String? _selectedHumanAgent;

  Widget _buildStatusFilter() {
    return _buildDropdown<String>(
      label: 'Status',
      value: _selectedStatus,
      items: FilterOptions.statusOptions,
      itemBuilder: (status) => status,
      onChanged: (status) {
        setState(() {
          _selectedStatus = status;
        });
      },
    );
  }

  Widget _buildMuteAiAgentFilter() {
    return _buildDropdown<String>(
      label: 'Is Mute Ai Agent',
      value: _selectedMuteAiAgent,
      items: FilterOptions.muteAiAgentOptions,
      itemBuilder: (option) => option,
      onChanged: (option) {
        setState(() {
          _selectedMuteAiAgent = option;
        });
      },
    );
  }

  Widget _buildReadStatusFilter() {
    return _buildDropdown<String>(
      label: 'Read Status',
      value: _selectedReadStatus,
      items: ['Read', 'Unread'],
      itemBuilder: (status) => status,
      onChanged: (status) {
        setState(() {
          _selectedReadStatus = status;
        });
      },
    );
  }

  Widget _buildChannelFilter() {
    return _buildDropdown<String>(
      label: 'Channel',
      value: _selectedChannel,
      items: FilterOptions.channelOptions,
      itemBuilder: (channel) => channel,
      onChanged: (channel) {
        setState(() {
          _selectedChannel = channel;
        });
      },
    );
  }

  Widget _buildChatTypeFilter() {
    return _buildDropdown<String>(
      label: 'Chat',
      value: _selectedChatType,
      items: FilterOptions.chatTypeOptions,
      itemBuilder: (chat) => chat,
      onChanged: (chat) {
        setState(() {
          _selectedChatType = chat;
        });
      },
    );
  }

  Widget _buildAccountFilter() {
    return _buildDropdown<String>(
      label: 'Account',
      value: _selectedAccount,
      items: FilterOptions.accountOptions,
      itemBuilder: (account) => account,
      onChanged: (account) {
        setState(() {
          _selectedAccount = account;
        });
      },
    );
  }

  Widget _buildContactFilter() {
    final contactOptions = FilterOptions.getContactOptions(widget.contacts);
    return _buildDropdown<String>(
      label: 'Contact',
      value: _selectedContact,
      items: contactOptions,
      itemBuilder: (contact) => contact,
      onChanged: (contact) {
        setState(() {
          _selectedContact = contact;
        });
      },
    );
  }

  Widget _buildLinkFilter() {
    final linkOptions = FilterOptions.getLinkOptions(widget.chatLinks);
    return _buildDropdown<String>(
      label: 'Link',
      value: _selectedLink,
      items: linkOptions,
      itemBuilder: (link) => link,
      onChanged: (link) {
        setState(() {
          _selectedLink = link;
        });
      },
    );
  }

  Widget _buildGroupFilter() {
    final groupOptions = FilterOptions.getGroupOptions(widget.chatLinks);
    return _buildDropdown<String>(
      label: 'Group',
      value: _selectedGroup,
      items: groupOptions,
      itemBuilder: (group) => group,
      onChanged: (group) {
        setState(() {
          _selectedGroup = group;
        });
      },
    );
  }

  Widget _buildCampaignFilter() {
    return _buildDropdown<String>(
      label: 'Campaign',
      value: _selectedCampaign,
      items: [],
      itemBuilder: (campaign) => campaign,
      onChanged: (campaign) {
        setState(() {
          _selectedCampaign = campaign;
        });
      },
      showNoMatches: true,
    );
  }

  Widget _buildFunnelFilter() {
    return _buildDropdown<String>(
      label: 'Funnel',
      value: _selectedFunnel,
      items: [],
      itemBuilder: (funnel) => funnel,
      onChanged: (funnel) {
        setState(() {
          _selectedFunnel = funnel;
        });
      },
      showNoMatches: true,
    );
  }

  Widget _buildDealFilter() {
    return _buildDropdown<String>(
      label: 'Deal',
      value: _selectedDeal,
      items: [],
      itemBuilder: (deal) => deal,
      onChanged: (deal) {
        setState(() {
          _selectedDeal = deal;
        });
      },
      showNoMatches: true,
    );
  }

  Widget _buildTagsFilter() {
    return _buildDropdown<String>(
      label: 'Tags',
      value: _selectedTags,
      items: [],
      itemBuilder: (tag) => tag,
      onChanged: (tag) {
        setState(() {
          _selectedTags = tag;
        });
      },
      showNoMatches: true,
    );
  }

  Widget _buildHumanAgentsFilter() {
    return _buildDropdown<String>(
      label: 'Human Agents',
      value: _selectedHumanAgent,
      items: FilterOptions.humanAgentOptions,
      itemBuilder: (agent) => agent,
      onChanged: (agent) {
        setState(() {
          _selectedHumanAgent = agent;
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with blue background
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF007AFF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Filter Conversation',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontFamily: 'Poppins',
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  ),
                ],
              ),
            ),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status
                    _buildStatusFilter(),
                    const SizedBox(height: 14),

                    // Is Mute AI Agent
                    _buildMuteAiAgentFilter(),
                    const SizedBox(height: 14),

                    // Read Status
                    _buildReadStatusFilter(),
                    const SizedBox(height: 14),

                    // Channel
                    _buildChannelFilter(),
                    const SizedBox(height: 14),

                    // Chat Type
                    _buildChatTypeFilter(),
                    const SizedBox(height: 14),

                    // Account
                    _buildAccountFilter(),
                    const SizedBox(height: 14),

                    // Contact
                    _buildContactFilter(),
                    const SizedBox(height: 14),

                    // Link
                    _buildLinkFilter(),
                    const SizedBox(height: 14),

                    // Group
                    _buildGroupFilter(),
                    const SizedBox(height: 14),

                    // Campaign
                    _buildCampaignFilter(),
                    const SizedBox(height: 14),

                    // Funnel
                    _buildFunnelFilter(),
                    const SizedBox(height: 14),

                    // Deal
                    _buildDealFilter(),
                    const SizedBox(height: 14),

                    // Tags
                    _buildTagsFilter(),
                    const SizedBox(height: 14),

                    // Human Agents
                    _buildHumanAgentsFilter(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Footer buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFFE0E0E0), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _selectedStatus = null;
                          _selectedMuteAiAgent = null;
                          _selectedReadStatus = null;
                          _selectedChannel = null;
                          _selectedChatType = null;
                          _selectedAccount = null;
                          _selectedContact = null;
                          _selectedLink = null;
                          _selectedGroup = null;
                          _selectedCampaign = null;
                          _selectedFunnel = null;
                          _selectedDeal = null;
                          _selectedTags = null;
                          _selectedHumanAgent = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                      ),
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Create filter with selected values
                        final filter = _tempFilter.copyWith(
                          selectedStatus: _selectedStatus != null ? {_selectedStatus!} : <String>{},
                          selectedMuteAiAgent: _selectedMuteAiAgent != null ? {_selectedMuteAiAgent!} : <String>{},
                          selectedChannels: _selectedChannel != null ? {_selectedChannel!} : <String>{},
                          selectedChatTypes: _selectedChatType != null ? {_selectedChatType!} : <String>{},
                          selectedAccounts: _selectedAccount != null ? {_selectedAccount!} : <String>{},
                          selectedContacts: _selectedContact != null ? {_selectedContact!} : <String>{},
                          selectedLinks: _selectedLink != null ? {_selectedLink!} : <String>{},
                          selectedGroups: _selectedGroup != null ? {_selectedGroup!} : <String>{},
                          selectedCampaigns: _selectedCampaign != null ? {_selectedCampaign!} : <String>{},
                          selectedFunnels: _selectedFunnel != null ? {_selectedFunnel!} : <String>{},
                          selectedDeals: _selectedDeal != null ? {_selectedDeal!} : <String>{},
                          selectedTags: _selectedTags != null ? {_selectedTags!} : <String>{},
                          selectedHumanAgents: _selectedHumanAgent != null ? {_selectedHumanAgent!} : <String>{},
                        );
                        widget.onApplyFilter(filter);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}