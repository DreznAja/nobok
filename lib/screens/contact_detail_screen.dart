import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Import this in your main ChatRoomScreen file
// import 'contact_detail_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final String contactName;
  final String contactId;
  final String? phoneNumber;
  final String? lastSeen;
  final String accountType;
  final bool needReply;
  final bool muteAiAgent;
  final List<String>? messageTags;
  final String? notes;
  final String? campaign;
  final String? deal;
  final String? formTemplate;
  final String? formResult;
  final List<String>? humanAgents;
  final String? createdDate;
  final String? lastSeenDate;

  const ContactDetailScreen({
    Key? key,
    required this.contactName,
    required this.contactId,
    this.phoneNumber,
    this.lastSeen,
    this.accountType = 'Bot',
    this.needReply = false,
    this.muteAiAgent = false,
    this.messageTags,
    this.notes,
    this.campaign,
    this.deal,
    this.formTemplate,
    this.formResult,
    this.humanAgents,
    this.createdDate,
    this.lastSeenDate,
  }) : super(key: key);

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  // Colors - matching your chat screen
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color lightBlue = Color(0xFF64B5F6);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color errorRed = Color(0xFFF44336);

  bool needReply = false;
  bool muteAiAgent = false;

  @override
  void initState() {
    super.initState();
    needReply = widget.needReply;
    muteAiAgent = widget.muteAiAgent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: surfaceWhite,
        foregroundColor: textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.contactName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            if (widget.phoneNumber != null)
              Text(
                widget.phoneNumber!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: successGreen,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: textSecondary),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Conversation History
          _buildListTile(
            title: 'Conversation History',
            trailing: const Icon(Icons.chevron_right, color: textSecondary, size: 20),
            onTap: () => Navigator.pop(context),
          ),
          
          _buildDivider(),
          
          // Contact Section Header
          _buildSectionHeader('Contact'),
          
          // Name
          _buildEditableRow(
            label: 'Name',
            value: widget.contactName,
            valueColor: primaryBlue,
            onEdit: () {},
          ),
          
          _buildDivider(),
          
          // Conversation Section Header  
          _buildSectionHeader('Conversation'),
          
          // Account Type
          _buildSimpleRow('Account', widget.accountType, valueColor: primaryBlue),
          
          // Need Reply Toggle
          _buildToggleRow('Need Reply', needReply, (value) {
            setState(() => needReply = value);
          }),
          
          // Mute AI Agent Toggle
          _buildToggleRow('Mute AI Agent', muteAiAgent, (value) {
            setState(() => muteAiAgent = value);
          }),
          
          _buildDivider(),
          
          // Funnel
          _buildExpandableRow(
            title: 'Funnel',
            content: 'Select funnel',
            isEmpty: true,
            onTap: () {},
          ),
          
          // Message Tags
          _buildExpandableRow(
            title: 'Message Tags',
            content: widget.messageTags?.join(', '),
            isEmpty: widget.messageTags?.isEmpty ?? true,
            onTap: () {},
          ),
          
          // Notes
          _buildExpandableRow(
            title: 'Notes',
            content: widget.notes,
            isEmpty: widget.notes?.isEmpty ?? true,
            onTap: () {},
          ),
          
          // Campaign
          _buildExpandableRow(
            title: 'Campaign',
            content: widget.campaign,
            isEmpty: widget.campaign?.isEmpty ?? true,
            hasEditIcon: true,
            onTap: () {},
          ),
          
          // Deal
          _buildExpandableRow(
            title: 'Deal',
            content: widget.deal,
            isEmpty: widget.deal?.isEmpty ?? true,
            hasEditIcon: true,
            onTap: () {},
          ),
          
          // Form Template
          _buildExpandableRow(
            title: 'Form Template',
            content: widget.formTemplate,
            isEmpty: widget.formTemplate?.isEmpty ?? true,
            hasEditIcon: true,
            onTap: () {},
          ),
          
          // Form Result
          _buildExpandableRow(
            title: 'Form Result',
            content: widget.formResult,
            isEmpty: widget.formResult?.isEmpty ?? true,
            onTap: () {},
          ),
          
          _buildDivider(),
          
          // Human Agents Section Header
          _buildSectionHeader('Human Agents'),
          
          // Human Agents List
          if (widget.humanAgents?.isNotEmpty ?? false)
            ...widget.humanAgents!.map((agent) => _buildAgentRow(agent))
          else
            _buildEmptyAgentRow(),
            
          _buildDivider(),
          
          // Other Section Header
          _buildSectionHeader('Other'),
          
          // Created Date
          _buildSimpleRow(
            'Created', 
            widget.createdDate ?? 'Not available',
            valueColor: widget.createdDate != null ? textPrimary : textSecondary,
          ),
          
          // Last Seen Date
          _buildSimpleRow(
            'Last Seen', 
            widget.lastSeenDate ?? 'Not available',
            valueColor: widget.lastSeenDate != null ? textPrimary : textSecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildListTile({
    required String title,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      color: surfaceWhite,
      child: ListTile(
        title: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textPrimary,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textSecondary,
        ),
      ),
    );
  }

  Widget _buildSimpleRow(String label, String value, {Color? valueColor}) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: valueColor ?? textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableRow({
    required String label,
    required String value,
    Color? valueColor,
    VoidCallback? onEdit,
  }) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: valueColor ?? textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.edit_outlined,
            size: 16,
            color: primaryBlue,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: primaryBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableRow({
    required String title,
    String? content,
    bool isEmpty = true,
    bool hasEditIcon = false,
    VoidCallback? onTap,
  }) {
    return Container(
      color: surfaceWhite,
      child: Column(
        children: [
          // Title row with add button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                if (hasEditIcon)
                  Icon(
                    Icons.edit_outlined,
                    size: 16,
                    color: primaryBlue,
                  ),
                const SizedBox(width: 8),
                Icon(
                  Icons.add,
                  size: 20,
                  color: primaryBlue,
                ),
              ],
            ),
          ),
          // Content row
          if (isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Not Set',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: errorRed,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                content ?? '',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentRow(String agentName) {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          // Name
          Expanded(
            child: Text(
              agentName,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: textPrimary,
              ),
            ),
          ),
          // Remove button
          Icon(
            Icons.close,
            size: 20,
            color: errorRed,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyAgentRow() {
    return Container(
      color: surfaceWhite,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Text(
        'No human agents assigned',
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: textSecondary,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 8,
      color: backgroundColor,
    );
  }
}