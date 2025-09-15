import 'package:flutter/material.dart';

/// Channel renderer utility based on the JavaScript implementation
class ChannelRenderer {
  
  /// Render channel icon for conversation list
  static Widget renderChannelIcon(int channelId, {double size = 24}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: _getChannelIcon(channelId, size),
    );
  }
  
  /// Get channel icon widget
  static Widget _getChannelIcon(int channelId, double size) {
    switch (channelId) {
      case 1:
      case 1557:
        return _buildIconContainer(
          Icons.chat,
          Colors.green,
          size,
          'WhatsApp',
        );
      case 2:
        return _buildIconContainer(
          Icons.telegram,
          Colors.blue,
          size,
          'Telegram',
        );
      case 3:
        return _buildIconContainer(
          Icons.camera_alt,
          Colors.purple,
          size,
          'Instagram',
        );
      case 4:
        return _buildIconContainer(
          Icons.facebook,
          Colors.blue[800]!,
          size,
          'Messenger',
        );
      case 19:
        return _buildIconContainer(
          Icons.email,
          Colors.red,
          size,
          'Email',
        );
      case 7:
        return _buildIconContainer(
          Icons.facebook,
          Colors.blue[800]!,
          size,
          'Messenger',
        );
      case 8:
        return _buildIconContainer(
          Icons.alternate_email,
          Colors.lightBlue,
          size,
          'Twitter',
        );
      case 1492:
        return _buildIconContainer(
          Icons.shopping_bag,
          Colors.red,
          size,
          'Bukalapak',
        );
      case 1502:
        return _buildIconContainer(
          Icons.shopping_cart,
          Colors.blue,
          size,
          'Blibli',
        );
      case 1556:
        return _buildIconContainer(
          Icons.store,
          Colors.blue,
          size,
          'Blibli Seller',
        );
      case 1503:
        return _buildIconContainer(
          Icons.shopping_basket,
          Colors.orange,
          size,
          'Lazada',
        );
      case 1504:
        return _buildIconContainer(
          Icons.shopping_bag,
          Colors.orange[800]!,
          size,
          'Shopee',
        );
      case 1505:
      case 1562:
        return _buildIconContainer(
          Icons.store,
          Colors.green,
          size,
          'Tokopedia',
        );
      case 1532:
        return _buildIconContainer(
          Icons.local_offer,
          Colors.purple,
          size,
          'OLX',
        );
      case 6:
        return _buildIconContainer(
          Icons.music_note,
          Colors.black,
          size,
          'TikTok',
        );
      case 1569:
        return _buildIconContainer(
          Icons.chat_bubble,
          Colors.blue,
          size,
          'NoboxChat',
        );
      default:
        return _buildIconContainer(
          Icons.chat,
          Colors.grey,
          size,
          'Unknown',
        );
    }
  }
  
  /// Build icon container with color and tooltip
  static Widget _buildIconContainer(
    IconData icon,
    Color color,
    double size,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: color,
          size: size * 0.6,
        ),
      ),
    );
  }
  
  /// Get channel name
  static String getChannelName(int channelId) {
    switch (channelId) {
      case 1:
      case 1557:
        return 'WhatsApp';
      case 2:
        return 'Telegram';
      case 3:
        return 'Instagram';
      case 4:
      case 7:
        return 'Messenger';
      case 19:
        return 'Email';
      case 8:
        return 'Twitter';
      case 1492:
        return 'Bukalapak';
      case 1502:
        return 'Blibli';
      case 1556:
        return 'Blibli Seller';
      case 1503:
        return 'Lazada';
      case 1504:
        return 'Shopee';
      case 1505:
      case 1562:
        return 'Tokopedia';
      case 1532:
        return 'OLX';
      case 6:
        return 'TikTok';
      case 1569:
        return 'NoboxChat';
      default:
        return 'Unknown Channel';
    }
  }
  
  /// Get channel color
  static Color getChannelColor(int channelId) {
    switch (channelId) {
      case 1:
      case 1557:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.purple;
      case 4:
      case 7:
        return Colors.blue[800]!;
      case 19:
        return Colors.red;
      case 8:
        return Colors.lightBlue;
      case 1492:
        return Colors.red;
      case 1502:
      case 1556:
        return Colors.blue;
      case 1503:
        return Colors.orange;
      case 1504:
        return Colors.orange[800]!;
      case 1505:
      case 1562:
        return Colors.green;
      case 1532:
        return Colors.purple;
      case 6:
        return Colors.black;
      case 1569:
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
  
  /// Check if channel supports voice messages
  static bool supportsVoiceMessages(int channelId) {
    switch (channelId) {
      case 1: // WhatsApp
      case 1557: // WhatsApp Business
      case 2: // Telegram
      case 1532: // OLX
        return true;
      default:
        return false;
    }
  }
  
  /// Check if channel supports file uploads
  static bool supportsFileUploads(int channelId) {
    switch (channelId) {
      case 1: // WhatsApp
      case 1557: // WhatsApp Business
      case 2: // Telegram
      case 19: // Email
        return true;
      default:
        return false;
    }
  }
  
  /// Check if channel supports location sharing
  static bool supportsLocationSharing(int channelId) {
    switch (channelId) {
      case 1: // WhatsApp
      case 1557: // WhatsApp Business
      case 2: // Telegram
      case 1532: // OLX
        return true;
      default:
        return false;
    }
  }
  
  /// Check if channel supports contacts sharing
  static bool supportsContactSharing(int channelId) {
    switch (channelId) {
      case 1557: // WhatsApp Business
        return true;
      default:
        return false;
    }
  }
  
  /// Check if channel supports stickers
  static bool supportsStickers(int channelId) {
    switch (channelId) {
      case 1557: // WhatsApp Business
      case 2: // Telegram
        return true;
      default:
        return false;
    }
  }
  
  /// Check if channel supports video input
  static bool supportsVideoInput(int channelId) {
    switch (channelId) {
      case 3: // Instagram
        return true;
      default:
        return false;
    }
  }
  
  /// Get channel capabilities
  static ChannelCapabilities getChannelCapabilities(int channelId) {
    return ChannelCapabilities(
      channelId: channelId,
      name: getChannelName(channelId),
      color: getChannelColor(channelId),
      supportsVoice: supportsVoiceMessages(channelId),
      supportsFiles: supportsFileUploads(channelId),
      supportsLocation: supportsLocationSharing(channelId),
      supportsContacts: supportsContactSharing(channelId),
      supportsStickers: supportsStickers(channelId),
      supportsVideo: supportsVideoInput(channelId),
    );
  }
  
  /// Render channel info for detail conversation
  static Widget renderChannelDetail({
    required int channelId,
    required String contactIdExt,
    required bool isGroup,
    String? groupIdExt,
  }) {
    final channelName = getChannelName(channelId);
    final channelIcon = renderChannelIcon(channelId, size: 20);
    
    String displayText = contactIdExt;
    
    // Special handling for groups
    if (isGroup && groupIdExt != null) {
      displayText = groupIdExt;
    }
    
    // Special handling for NoboxChat (truncate long IDs)
    if (channelId == 1569 && displayText.length > 25) {
      displayText = '${displayText.substring(0, 25)}...';
    }
    
    return Row(
      children: [
        channelIcon,
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            displayText,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          channelName,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

/// Channel capabilities model
class ChannelCapabilities {
  final int channelId;
  final String name;
  final Color color;
  final bool supportsVoice;
  final bool supportsFiles;
  final bool supportsLocation;
  final bool supportsContacts;
  final bool supportsStickers;
  final bool supportsVideo;

  ChannelCapabilities({
    required this.channelId,
    required this.name,
    required this.color,
    required this.supportsVoice,
    required this.supportsFiles,
    required this.supportsLocation,
    required this.supportsContacts,
    required this.supportsStickers,
    required this.supportsVideo,
  });

  @override
  String toString() {
    return 'ChannelCapabilities{channelId: $channelId, name: $name, voice: $supportsVoice, files: $supportsFiles}';
  }
}