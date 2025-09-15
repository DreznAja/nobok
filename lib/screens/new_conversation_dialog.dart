import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/filter_model.dart'; // Import untuk akses FilterOptions
import '../screens/chat_room_screen.dart';

class NewConversationDialog extends StatefulWidget {
  final List<ChannelModel> channels;
  final List<AccountModel> accounts;
  final List<ContactModel> contacts;
  final Function(Map<String, dynamic>) onConversationCreated;

  const NewConversationDialog({
    Key? key,
    required this.channels,
    required this.accounts,
    required this.contacts,
    required this.onConversationCreated,
  }) : super(key: key);

  @override
  State<NewConversationDialog> createState() => _NewConversationDialogState();
}

class _NewConversationDialogState extends State<NewConversationDialog> {
  // Form states
  String _selectedChatType = 'Private'; // Private or Group
  String? _selectedChannel; // ✅ CHANGED: Now use String instead of ChannelModel
  String? _selectedAccount; // ✅ CHANGED: Now dynamic based on channel
  String _selectedToType = 'Contact'; // Contact, Link, or Manual
  ContactModel? _selectedContact;
  LinkModel? _selectedLink; // ✅ NEW: For link selection
  String _manualInput = '';
  bool _isLoading = false;
  
  // ✅ NEW: State untuk link data dan loading
  List<LinkModel> _availableLinks = [];
  bool _isLoadingLinks = false;
  
  // ✅ NEW: State untuk account data dan loading
  List<AccountModel> _availableAccounts = [];
  bool _isLoadingAccounts = false;

  // Colors matching the main app design
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);

  // ✅ FIXED: Gunakan channel list yang sudah dibatasi dari FilterOptions
  List<String> get _limitedChannels {
    return FilterOptions.channelOptions; // ['Mobile Number', 'NoboxChat', 'Telegram', 'Tokopedia.com', 'WhatsApp']
  }

  @override
  void initState() {
    super.initState();
    // ✅ FIXED: Set default channel dari limited list
    if (_limitedChannels.isNotEmpty) {
      _selectedChannel = _limitedChannels.first;
      // ✅ NEW: Load links dan accounts untuk channel default
      _loadDataForSelectedChannel();
    }
  }

  // ✅ NEW: Master method untuk load links dan accounts berdasarkan channel
  Future<void> _loadDataForSelectedChannel() async {
    if (_selectedChannel == null) return;
    
    // Load links dan accounts secara parallel
    await Future.wait([
      _loadLinksForChannel(),
      _loadAccountsForChannel(),
    ]);
  }

  // ✅ ENHANCED: Method untuk load links berdasarkan channel yang dipilih dengan validasi ketat
Future<void> _loadLinksForChannel() async {
  if (_selectedChannel == null) return;
  if (widget.channels.isEmpty) {
    _showError('No channels available');
    return;
  }

  // Cari matching channel, fallback ke channel pertama (non-null)
  ChannelModel selectedChannelModel = _findChannelByName(_selectedChannel!) ?? widget.channels.first;

  // Jika channel terpilih adalah WhatsApp, ambil links dari Mobile Number channel
  if (selectedChannelModel.name.toLowerCase() == 'whatsapp') {
    final mobileChannel = widget.channels.firstWhere(
      (c) => c.name.toLowerCase() == 'mobile number',
      orElse: () => widget.channels.first, // <-- non-null fallback
    );
    selectedChannelModel = mobileChannel;
  }

  setState(() {
    _isLoadingLinks = true;
    _availableLinks.clear();
    _selectedLink = null;
  });

  try {
    print('🔥 Loading links for channel (using channel id): ${selectedChannelModel.name} (ID: ${selectedChannelModel.id})');

    final response = await ApiService.getLinkList(
      channelId: selectedChannelModel.id,
      take: 100,
      skip: 0,
    );

    if (response.success && response.data != null) {
      setState(() {
        _availableLinks = response.data!;
        print('🔥 ✅ Loaded ${_availableLinks.length} links for channel ${selectedChannelModel.name}');
      });
    } else {
      print('🔥 ❌ Failed to load links: ${response.message}');
      // jangan terlalu spam _showError di sini, tapi boleh jika perlu
    }
  } catch (e) {
    print('🔥 ❌ Error loading links: $e');
    _showError('Error loading links: $e');
  } finally {
    setState(() {
      _isLoadingLinks = false;
    });
  }
}


  // ✅ NEW: Method untuk load accounts berdasarkan channel yang dipilih
  Future<void> _loadAccountsForChannel() async {
    if (_selectedChannel == null) return;
    
    // Find matching channel model
    final selectedChannelModel = _findChannelByName(_selectedChannel!);
    if (selectedChannelModel == null) return;

    setState(() {
      _isLoadingAccounts = true;
      _availableAccounts.clear();
      _selectedAccount = null;
    });

    try {
      print('🔥 Loading accounts for channel: ${selectedChannelModel.name} (ID: ${selectedChannelModel.id})');
      
      final response = await ApiService.getAccounts(
        channelId: selectedChannelModel.id,
      );

      if (response.success && response.data != null && response.data!.isNotEmpty) {
        setState(() {
          _availableAccounts = response.data!;
          // ✅ CRITICAL: Set default account to first available account
          _selectedAccount = _availableAccounts.first.name;
          print('🔥 ✅ Loaded ${_availableAccounts.length} accounts for channel ${selectedChannelModel.name}');
          print('🔥 Default account set to: ${_selectedAccount}');
        });
      } else {
        setState(() {
          _availableAccounts = [];
          _selectedAccount = null;
        });
        print('🔥 ⚠️ No accounts found for channel ${selectedChannelModel.name}');
        _showError('No accounts available for selected channel');
      }
    } catch (e) {
      print('🔥 ❌ Error loading accounts: $e');
      _showError('Error loading accounts: $e');
      setState(() {
        _availableAccounts = [];
        _selectedAccount = null;
      });
    } finally {
      setState(() {
        _isLoadingAccounts = false;
      });
    }
  }

  // ✅ FIXED: Find matching channel model dari nama channel yang dipilih
  ChannelModel? _findChannelByName(String channelName) {
    try {
      return widget.channels.firstWhere(
        (channel) => channel.name.toLowerCase().contains(channelName.toLowerCase()) ||
                     channelName.toLowerCase().contains(channel.name.toLowerCase()),
      );
    } catch (e) {
      // Jika tidak ditemukan exact match, ambil channel pertama sebagai fallback
      return widget.channels.isNotEmpty ? widget.channels.first : null;
    }
  }

  // ✅ ENHANCED: Validasi compatibility antara channel, contact, dan link
  bool _validateChannelCompatibility() {
    if (_selectedChannel == null) {
      _showError('Please select a channel');
      return false;
    }

    final selectedChannelModel = _findChannelByName(_selectedChannel!);
    if (selectedChannelModel == null) {
      _showError('Selected channel is not available');
      return false;
    }

    // ✅ CRITICAL: Validasi account availability
    if (_availableAccounts.isEmpty) {
      _showError('No accounts available for selected channel');
      return false;
    }

    if (_selectedAccount == null || _selectedAccount!.isEmpty) {
      _showError('Please select an account');
      return false;
    }

    // ✅ CRITICAL: Validasi account compatibility dengan channel
    final selectedAccountModel = _availableAccounts.where(
      (account) => account.name == _selectedAccount
    ).firstOrNull;

    if (selectedAccountModel == null) {
      _showError('Selected account is not available for this channel');
      return false;
    }

    if (selectedAccountModel.channel != selectedChannelModel.id) {
      _showError('Selected account does not belong to the selected channel');
      return false;
    }

    // ✅ CRITICAL: Validasi contact/link compatibility untuk Private chat
    if (_selectedChatType == 'Private') {
      if (_selectedToType == 'Contact' && _selectedContact != null) {
        // Validasi bahwa contact ini valid untuk channel yang dipilih
        // Contact bisa digunakan di semua channel, jadi tidak perlu validasi khusus
        return true;
      } else if (_selectedToType == 'Link' && _selectedLink != null) {
        // ✅ CRITICAL: Validasi bahwa link ini benar-benar dari channel yang dipilih
        final linkBelongsToChannel = _availableLinks.any(
          (link) => link.id == _selectedLink!.id && link.idExt == _selectedLink!.idExt
        );
        
        if (!linkBelongsToChannel) {
          _showError('Selected link does not belong to the selected channel');
          return false;
        }
        return true;
      } else if (_selectedToType == 'Manual' && _manualInput.trim().isNotEmpty) {
        // Manual input bisa digunakan di semua channel
        return true;
      } else {
        _showError('Please complete all required fields');
        return false;
      }
    }

    return true;
  }

  // ✅ CRITICAL FIX: Cari existing ChatLinkModel dengan message history
  Future<ChatLinkModel?> _findExistingChatLink({
    required String contactName,
    required String linkIdExt,
    required int channelId,
  }) async {
    try {
      print('🔥 === SEARCHING FOR EXISTING CHAT LINK ===');
      print('🔥 Contact: $contactName');
      print('🔥 LinkIdExt: $linkIdExt');
      print('🔥 ChannelId: $channelId');

      // ✅ STEP 1: Search by linkIdExt terlebih dahulu (paling akurat)
      if (linkIdExt.isNotEmpty) {
        final response1 = await ApiService.getChatLinks(
          channelId: channelId,
          take: 100,
          skip: 0,
        );

        if (response1.success && response1.data != null) {
          // Cari yang IdExt match
          final exactMatch = response1.data!.firstWhere(
            (chatLink) => chatLink.idExt == linkIdExt,
            orElse: () => ChatLinkModel(id: '', idExt: '', name: ''),
          );

          if (exactMatch.id.isNotEmpty) {
            print('🔥 ✅ FOUND EXISTING CHAT by IdExt: ${exactMatch.name} (ID: ${exactMatch.id}, IdExt: ${exactMatch.idExt})');
            print('🔥 ✅ This chat should have existing message history!');
            return exactMatch;
          }
        }
      }

      // ✅ STEP 2: Search by contact name jika IdExt tidak ditemukan
      if (contactName.isNotEmpty) {
        final response2 = await ApiService.getChatLinks(
          channelId: channelId,
          take: 200, // Lebih banyak untuk pencarian nama
          skip: 0,
        );

        if (response2.success && response2.data != null) {
          // Cari yang nama mirip/sama
          final nameMatches = response2.data!.where((chatLink) {
            final chatName = chatLink.name.toLowerCase();
            final searchName = contactName.toLowerCase();
            return chatName.contains(searchName) || searchName.contains(chatName);
          }).toList();

          if (nameMatches.isNotEmpty) {
            // Ambil yang paling mirip (exact match dulu, lalu yang mengandung)
            final exactNameMatch = nameMatches.firstWhere(
              (chatLink) => chatLink.name.toLowerCase() == contactName.toLowerCase(),
              orElse: () => nameMatches.first, // fallback ke yang pertama
            );

            print('🔥 ✅ FOUND EXISTING CHAT by Name: ${exactNameMatch.name} (ID: ${exactNameMatch.id}, IdExt: ${exactNameMatch.idExt})');
            return exactNameMatch;
          }
        }
      }

      print('🔥 ❌ NO EXISTING CHAT FOUND');
      return null;

    } catch (e) {
      print('🔥 Error searching existing chat link: $e');
      return null;
    }
  }

void _createConversation() async {
  if (!_validateChannelCompatibility()) {
    return;
  }

  setState(() => _isLoading = true);

  try {
    String contactName = '';
    String linkIdExt = '';
    int linkId = 0;
    ChatLinkModel? existingChatLink;

    // ==== CASE: Contact ====
    if (_selectedToType == 'Contact' && _selectedContact != null) {
      contactName = _selectedContact!.name;

      // 🔥 Cari semua link dari server untuk channel ini
      final response = await ApiService.getLinkList(
        channelId: _findChannelByName(_selectedChannel!)?.id ?? 0,
        take: 100,
        skip: 0,
      );

      if (response.success && response.data != null) {
        // Cocokkan link dengan Contact ID
        final matchingLink = response.data!.firstWhere(
  (link) => link.name.toLowerCase() == _selectedContact!.name.toLowerCase(),
  orElse: () => LinkModel(id: '', idExt: '', name: ''),
);


        if (matchingLink.id.isNotEmpty) {
          print("🔥 Contact ${_selectedContact!.name} → Link ${matchingLink.idExt}");
          _selectedLink = matchingLink;
          _selectedToType = 'Link'; // switch ke link

          linkIdExt = matchingLink.idExt;
          linkId = int.tryParse(matchingLink.id) ?? 0;

          // cari chat link existing
          final resp2 = await ApiService.getChatLinks(
            channelId: _findChannelByName(_selectedChannel!)!.id,
            take: 100,
            skip: 0,
          );
          if (resp2.success && resp2.data != null) {
            existingChatLink = resp2.data!.firstWhere(
              (c) => c.idExt == matchingLink.idExt,
              orElse: () => ChatLinkModel(id: '', idExt: '', name: ''),
            );
            if (existingChatLink.id.isEmpty) existingChatLink = null;
          }
        } else {
          _showError("Contact ${_selectedContact!.name} tidak punya Link");
          setState(() => _isLoading = false);
          return;
        }
      }
    }

    // ==== CASE: Link ====
    else if (_selectedToType == 'Link' && _selectedLink != null) {
      contactName = _selectedLink!.name;
      linkIdExt = _selectedLink!.idExt;
      linkId = int.tryParse(_selectedLink!.id) ?? 0;

      print('🔥 Using Link: $contactName (ID: $linkId, IdExt: $linkIdExt)');

      final response = await ApiService.getChatLinks(
        channelId: _findChannelByName(_selectedChannel!)?.id ?? 0,
        take: 100,
        skip: 0,
      );
      if (response.success && response.data != null) {
        existingChatLink = response.data!.firstWhere(
          (c) => c.idExt == _selectedLink!.idExt,
          orElse: () => ChatLinkModel(id: '', idExt: '', name: ''),
        );
        if (existingChatLink.id.isEmpty) existingChatLink = null;
      }
    }

    // ==== CASE: Manual ====
    else if (_selectedToType == 'Manual') {
      contactName = _manualInput.trim();
      linkIdExt = _manualInput.trim();
      linkId = int.tryParse(_manualInput.trim()) ?? 0;

      existingChatLink = await _findExistingChatLink(
        contactName: contactName,
        linkIdExt: linkIdExt,
        channelId: _findChannelByName(_selectedChannel!)?.id ?? 0,
      );
    }

    // ==== Validate channel/account ====
    final selectedChannelModel = _findChannelByName(_selectedChannel!);
    final selectedAccountModel = _availableAccounts
        .where((a) => a.name == _selectedAccount)
        .firstOrNull;

    if (selectedChannelModel == null || selectedAccountModel == null) {
      _showError('Channel/Account tidak valid');
      setState(() => _isLoading = false);
      return;
    }

    // ==== Navigate ====
    Navigator.of(context).pop();
    await _navigateToChatroomWithProperData(
      existingChatLink: existingChatLink,
      contactName: contactName,
      linkIdExt: linkIdExt,
      linkId: linkId,
      channelModel: selectedChannelModel,
      accountModel: selectedAccountModel,
    );
  } catch (e) {
    _showError('Failed to create conversation: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}




  // ✅ CRITICAL FIX: Navigate dengan existing data atau create new dengan proper message loading
Future<void> _navigateToChatroomWithProperData({
  ChatLinkModel? existingChatLink,
  required String contactName,
  required String linkIdExt,
  required int linkId,
  required ChannelModel channelModel,
  required AccountModel accountModel,
}) async {
  try {
    print('🔥 === NAVIGATING TO CHATROOM ===');

    // Pakai existing kalau ada, kalau enggak bikin lokal
    final chatLinkToUse = existingChatLink ??
        ChatLinkModel(
          id: linkId > 0
              ? linkId.toString()
              : DateTime.now().millisecondsSinceEpoch.toString(),
          idExt: linkIdExt,
          name: contactName.isNotEmpty ? contactName : 'New Contact',
        );

    print('🔥 ChatLink ready: ${chatLinkToUse.name} (ID: ${chatLinkToUse.id}, IdExt: ${chatLinkToUse.idExt})');

    final accounts = [accountModel];

    // ✅ Langsung push ke ChatRoomScreen
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatRoomScreen(
          chatLink: chatLinkToUse,
          channel: channelModel,
          accounts: accounts,
        ),
      ),
    );

    print('🔥 ✅ Successfully navigated to chatroom');
  } catch (e) {
    print('🔥 Error navigating to chatroom: $e');
    _showError('Failed to open chatroom: $e');
  }
}

  // ✅ NEW: Method untuk create new chat di server (opsional)
  Future<ChatLinkModel?> _createNewChatOnServer({
    required String contactName,
    required String linkIdExt,
    required int channelId,
    required String accountId,
  }) async {
    try {
      print('🔥 Attempting to create new chat on server...');
      
      // This is optional - you can implement server-side chat creation here
      // For now, we'll return null to use local fallback
      
      // Example implementation (uncomment and modify as needed):
      /*
      final response = await ApiService.createNewChatLink(
        name: contactName,
        idExt: linkIdExt,
        channelId: channelId,
        accountId: accountId,
      );
      
      if (response.success && response.data != null) {
        return response.data;
      }
      */
      
      return null;
    } catch (e) {
      print('🔥 Error creating new chat on server: $e');
      return null;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ✅ ENHANCED: Channel dropdown dengan auto-reload data ketika berubah
  Widget _buildChannelDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                'Channel',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: DropdownButton<String>(
            value: _selectedChannel,
            isExpanded: true,
            underline: const SizedBox(),
            hint: Text(
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
            // ✅ CRITICAL FIX: Gunakan _limitedChannels bukan widget.channels
            items: _limitedChannels.map((channelName) => DropdownMenuItem<String>(
              value: channelName,
              child: Text(channelName),
            )).toList(),
            onChanged: (channelName) {
              setState(() {
                _selectedChannel = channelName;
                // ✅ CRITICAL: Clear all selections when channel changes
                _selectedContact = null;
                _selectedLink = null;
                _selectedAccount = null;
                _manualInput = '';
                _availableLinks.clear();
                _availableAccounts.clear();
              });
              // ✅ NEW: Load data untuk channel baru
              _loadDataForSelectedChannel();
            },
          ),
        ),
      ],
    );
  }

  // ✅ NEW: Dynamic account dropdown berdasarkan channel
  Widget _buildAccountDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                'Account',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: _isLoadingAccounts
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading accounts...',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButton<String>(
                  value: _selectedAccount,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    _availableAccounts.isEmpty ? 'No accounts available' : '--select--',
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
                  items: _availableAccounts
                      .map((account) => DropdownMenuItem<String>(
                            value: account.name,
                            child: Text('${account.name} (ID: ${account.id})'),
                          ))
                      .toList(),
                  onChanged: _availableAccounts.isEmpty
                      ? null
                      : (accountName) {
                          setState(() {
                            _selectedAccount = accountName;
                          });
                          print('🔥 ✅ Account selected: $accountName');
                        },
                ),
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemBuilder,
    required void Function(T?) onChanged,
    bool enabled = true,
    bool required = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              if (required)
                Text(
                  ' *',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.red,
                    fontFamily: 'Poppins',
                  ),
                ),
            ],
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
            hint: Text(
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
            items: items.map((item) => DropdownMenuItem<T>(
              value: item,
              child: Text(itemBuilder(item)),
            )).toList(),
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildRadioGroup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'To',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  // Contact
                  // Expanded(
                  //   child: InkWell(
                  //     onTap: () {
                  //       setState(() {
                  //         _selectedToType = 'Contact';
                  //         // _selectedContact = null;
                  //         _selectedLink = null; // ✅ NEW: Clear link selection
                  //         _manualInput = '';
                  //       });
                  //     },
                  //     child: Row(
                  //       children: [
                  //         // Radio<String>(
                  //         //   value: 'Contact',
                  //         //   groupValue: _selectedToType,
                  //         //   onChanged: (value) {
                  //         //     setState(() {
                  //         //       _selectedToType = value!;
                  //         //       // _selectedContact = null;
                  //         //       _selectedLink = null; // ✅ NEW: Clear link selection
                  //         //       _manualInput = '';
                  //         //     });
                  //         //   },
                  //         //   activeColor: primaryBlue,
                  //         //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  //         // ),
                  //         // const Text(
                  //         //   'Contact',
                  //         //   style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                  //         // ),
                  //       ],
                  //     ),
                  //   ),
                  // ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _selectedToType = 'Link';
                          _selectedContact = null;
                          _selectedLink = null; // ✅ NEW: Clear link selection
                          _manualInput = '';
                        });
                      },
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'Link',
                            groupValue: _selectedToType,
                            onChanged: (value) {
                              setState(() {
                                _selectedToType = value!;
                                _selectedContact = null;
                                _selectedLink = null; // ✅ NEW: Clear link selection
                                _manualInput = '';
                              });
                            },
                            activeColor: primaryBlue,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          const Text(
                            'Link',
                            style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedToType = 'Manual';
                    _selectedContact = null;
                    _selectedLink = null; // ✅ NEW: Clear link selection
                    _manualInput = '';
                  });
                },
                child: Row(
                  children: [
                    // Radio<String>(
                    //   value: 'Manual',
                    //   groupValue: _selectedToType,
                    //   onChanged: (value) {
                    //     setState(() {
                    //       _selectedToType = value!;
                    //       _selectedContact = null;
                    //       _selectedLink = null; // ✅ NEW: Clear link selection
                    //       _manualInput = '';
                    //     });
                    //   },
                    //   activeColor: primaryBlue,
                    //   materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    // ),
                    // const Text(
                    //   'Manual',
                    //   style: TextStyle(fontSize: 13, fontFamily: 'Poppins'),
                    // ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ ENHANCED: Contact selection dengan validasi channel compatibility
Widget _buildContactSelection() {
  if (_selectedToType == 'Manual') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: Text(
            'Manual Input',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textPrimary,
              fontFamily: 'Poppins',
            ),
          ),
        ),
        TextField(
          onChanged: (value) {
            setState(() {
              _manualInput = value;
            });
          },
          decoration: InputDecoration(
            hintText: '62xxx or contact name',
            hintStyle: const TextStyle(color: textSecondary, fontSize: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: Color(0xFFE5E5E5), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: const BorderSide(color: primaryBlue, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 14, fontFamily: 'Poppins'),
        ),
      ],
    );
  } else if (_selectedToType == 'Link') {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Text(
                'Link',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: textPrimary,
                  fontFamily: 'Poppins',
                ),
              ),
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.red,
                  fontFamily: 'Poppins',
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E5E5), width: 1),
            borderRadius: BorderRadius.circular(6),
            color: Colors.white,
          ),
          child: _isLoadingLinks
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Loading links for channel...',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                )
              : DropdownButton<LinkModel>(
                  value: _selectedLink,
                  isExpanded: true,
                  underline: const SizedBox(),
                  hint: Text(
                    _availableLinks.isEmpty 
                        ? (_selectedChannel != null 
                            ? 'No links available for ${_selectedChannel}' 
                            : 'Select channel first')
                        : '--select link--',
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
                  items: _availableLinks
                      .map((link) => DropdownMenuItem<LinkModel>(
                            value: link,
                            child: Text('${link.name} (${link.idExt})'),
                          ))
                      .toList(),
                  onChanged: _availableLinks.isEmpty
                      ? null
                      : (link) {
                          setState(() {
                            _selectedLink = link;
                          });
                          print(
                              '🔥 ✅ EXISTING Link selected: ${link?.name} (ID: ${link?.id}, IdExt: ${link?.idExt})');
                        },
                ),
        ),
      ],
    );
  } else {
    // Contact selection (enhanced dengan info tambahan)
    return _buildDropdown<ContactModel>(
      label: 'Contact',
      value: _selectedContact,
      items: widget.contacts,
      itemBuilder: (contact) => '${contact.name} (ID: ${contact.id})',
      onChanged: (contact) {
        setState(() {
          _selectedContact = contact;
          _selectedLink = null; // ✅ clear link kalau pilih contact
        });
        print('🔥 ✅ Contact selected: ${contact?.name} (ID: ${contact?.id})');
      },
      required: true,
    );
  }
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
                    'New Conversation',
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
                    // Chat Type
                    _buildDropdown<String>(
                      label: 'Chat',
                      value: _selectedChatType,
                      items: ['Private', 'Group'],
                      itemBuilder: (type) => type,
                      onChanged: (type) {
                        setState(() {
                          _selectedChatType = type!;
                        });
                      },
                      required: true,
                    ),
                    const SizedBox(height: 14),

                    // ✅ ENHANCED: Channel dropdown dengan auto-reload
                    _buildChannelDropdown(),
                    const SizedBox(height: 14),

                    // ✅ NEW: Dynamic Account dropdown based on selected channel
                    _buildAccountDropdown(),
                    const SizedBox(height: 14),

                    // To radio buttons (hide for Group chat)
                    if (_selectedChatType == 'Private') ...[
                      _buildRadioGroup(),
                      const SizedBox(height: 14),
                    ],

                    // Contact/Link/Manual selection (hide for Group chat)
                    if (_selectedChatType == 'Private') ...[
                      _buildContactSelection(),
                      const SizedBox(height: 20),
                    ],
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
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
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
                      onPressed: (_isLoading || _isLoadingLinks || _isLoadingAccounts) 
                          ? null 
                          : _createConversation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        elevation: 0,
                      ),
                      child: (_isLoading || _isLoadingLinks || _isLoadingAccounts)
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Create',
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