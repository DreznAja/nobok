import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import '../models/message_model.dart';

class MessageBubbleRenderer {
  static const Color primaryBlue = Color(0xFF007AFF);
  static const Color myMessageBubble = Color(0xFF007AFF);
  static const Color otherMessageBubble = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color errorRed = Color(0xFFF44336);

  // Equivalent to JavaScript text() function
  static Widget buildTextMessage(NoboxMessage message, bool isFromMe) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isFromMe ? 18 : 4),
          bottomRight: Radius.circular(isFromMe ? 4 : 18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null) ...[
            _buildReplyWidget(message),
            const SizedBox(height: 8),
          ],
          _buildTextWithUrls(message.content, isFromMe),
        ],
      ),
    );
  }

  // Equivalent to JavaScript audio() function
  static Widget buildAudioMessage(NoboxMessage message, bool isFromMe) {
    final fileInfo = _parseFileInfo(message.file ?? '');
    final audioUrl = _resolveUrl(fileInfo['filename'] ?? '');
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null) ...[
            _buildReplyWidget(message),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(
                Icons.audiotrack,
                color: isFromMe ? Colors.white : textPrimary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Audio Message',
                      style: TextStyle(
                        color: isFromMe ? Colors.white : textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    if (fileInfo['fileSize'] != null)
                      Text(
                        fileInfo['fileSize']!,
                        style: TextStyle(
                          color: isFromMe ? Colors.white70 : textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _launchUrl(audioUrl),
                child: Icon(
                  Icons.play_circle_fill,
                  color: isFromMe ? Colors.white : primaryBlue,
                  size: 32,
                ),
              ),
            ],
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildTextWithUrls(message.content, isFromMe),
          ],
        ],
      ),
    );
  }

  // Equivalent to JavaScript image() function
  static Widget buildImageMessage(NoboxMessage message, bool isFromMe) {
    final fileInfo = _parseFileInfo(message.file ?? '');
    final imageUrl = _resolveUrl(fileInfo['filename'] ?? '');
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildReplyWidget(message),
            ),
          GestureDetector(
            onTap: () => _showImageViewer(imageUrl),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 200,
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    color: Colors.grey[200],
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildTextWithUrls(message.content, isFromMe),
            ),
        ],
      ),
    );
  }

  // Equivalent to JavaScript video() function
  static Widget buildVideoMessage(NoboxMessage message, bool isFromMe) {
    final fileInfo = _parseFileInfo(message.file ?? '');
    final videoUrl = _resolveUrl(fileInfo['filename'] ?? '');
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildReplyWidget(message),
            ),
          GestureDetector(
            onTap: () => _launchUrl(videoUrl),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.video_library,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (message.content.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: _buildTextWithUrls(message.content, isFromMe),
            ),
        ],
      ),
    );
  }

  // Equivalent to JavaScript document() function
  static Widget buildDocumentMessage(NoboxMessage message, bool isFromMe) {
    final fileInfo = _parseFileInfo(message.file ?? '');
    final documentUrl = _resolveUrl(fileInfo['filename'] ?? '');
    final fileName = fileInfo['originalName'] ?? 'Document';
    final fileSize = fileInfo['fileSize'] ?? '';
    final fileExtension = fileName.split('.').last.toUpperCase();
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null) ...[
            _buildReplyWidget(message),
            const SizedBox(height: 8),
          ],
          GestureDetector(
            onTap: () => _launchUrl(documentUrl),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isFromMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getFileIcon(fileExtension),
                    color: isFromMe ? Colors.white : textPrimary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName.length > 25 ? '${fileName.substring(0, 24)}...' : fileName,
                        style: TextStyle(
                          color: isFromMe ? Colors.white : textPrimary,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      if (fileSize.isNotEmpty)
                        Text(
                          '$fileSize • $fileExtension',
                          style: TextStyle(
                            color: isFromMe ? Colors.white70 : textSecondary,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (message.content.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildTextWithUrls(message.content, isFromMe),
          ],
        ],
      ),
    );
  }

  // Equivalent to JavaScript location() function
  static Widget buildLocationMessage(NoboxMessage message, bool isFromMe) {
    final locationData = message.content.split("[-{==}-]");
    final latitude = locationData.isNotEmpty ? locationData[0] : '';
    final longitude = locationData.length > 1 ? locationData[1] : '';
    final locationName = locationData.length > 2 ? locationData[2] : '';
    
    final mapUrl = locationName.isNotEmpty
        ? 'https://www.google.com/maps/search/$locationName/@$latitude,$longitude,21z'
        : 'https://www.google.com/maps?q=$latitude,$longitude&z=21';
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyId != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: _buildReplyWidget(message),
            ),
          GestureDetector(
            onTap: () => _launchUrl(mapUrl),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              child: Container(
                height: 165,
                width: double.infinity,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage('https://via.placeholder.com/280x165/4CAF50/FFFFFF?text=Map'),
                    fit: BoxFit.cover,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.location_on,
                    size: 48,
                    color: Colors.red,
                  ),
                ),
              ),
            ),
          ),
          if (locationName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Text(
                locationName,
                style: TextStyle(
                  color: isFromMe ? Colors.white : textPrimary,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Equivalent to JavaScript contact() function
  static Widget buildContactMessage(NoboxMessage message, bool isFromMe) {
    final contactData = _parseVCard(message.content);
    
    if (contactData.isEmpty) return const SizedBox.shrink();
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 306),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (message.replyId != null) ...[
            _buildReplyWidget(message),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isFromMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.person,
                  color: isFromMe ? Colors.white : textPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contactData['name'] ?? 'Unknown Contact',
                      style: TextStyle(
                        color: isFromMe ? Colors.white : textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    if (contactData['phone'] != null)
                      Text(
                        contactData['phone']!,
                        style: TextStyle(
                          color: isFromMe ? Colors.white70 : textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _downloadVCard(message.content),
                child: Icon(
                  Icons.download,
                  color: isFromMe ? Colors.white : primaryBlue,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Equivalent to JavaScript interactiveButton() function
  static Widget buildInteractiveButtonMessage(NoboxMessage message, bool isFromMe) {
    final jsonData = _parseJson(message.content);
    if (jsonData == null) return const SizedBox.shrink();
    
    final fileInfo = _parseFileInfo(message.file ?? '');
    
    return Container(
      constraints: const BoxConstraints(maxWidth: 275),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header content (image/video/document)
          if (jsonData['header'] != null && jsonData['header']['type'] != null)
            _buildInteractiveHeader(jsonData['header'], fileInfo),
          
          // Body and footer text
          if (jsonData['body'] != null || jsonData['footer'] != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (jsonData['header'] != null && jsonData['header']['text'] != null) ...[
                    Text(
                      jsonData['header']['text'],
                      style: TextStyle(
                        color: isFromMe ? Colors.white : textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (jsonData['body'] != null && jsonData['body']['text'] != null)
                    _buildTextWithUrls(jsonData['body']['text'], isFromMe),
                  if (jsonData['footer'] != null && jsonData['footer']['text'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      jsonData['footer']['text'],
                      style: TextStyle(
                        color: isFromMe ? Colors.white70 : textSecondary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          
          // Action buttons
          if (jsonData['action'] != null && jsonData['action']['buttons'] != null)
            _buildActionButtons(jsonData['action']['buttons'], isFromMe),
        ],
      ),
    );
  }

  // Equivalent to JavaScript unsupport() function
  static Widget buildUnsupportedMessage(NoboxMessage message, bool isFromMe) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFromMe ? myMessageBubble : otherMessageBubble,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          if (message.replyId != null) ...[
            _buildReplyWidget(message),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: isFromMe ? Colors.white : errorRed,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message.content.isNotEmpty 
                      ? message.content 
                      : 'Unsupported message type',
                  style: TextStyle(
                    color: isFromMe ? Colors.white70 : textSecondary,
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Helper methods
  static Widget _buildReplyWidget(NoboxMessage message) {
    // Implement reply message rendering based on your reply data structure
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: primaryBlue, width: 3)),
      ),
      child: const Text(
        'Replied message', // Replace with actual reply content
        style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
      ),
    );
  }

  static Widget _buildTextWithUrls(String text, bool isFromMe) {
    // Simple URL detection - you can enhance this with more sophisticated regex
    final urlRegex = RegExp(r'https?://[^\s]+');
    final matches = urlRegex.allMatches(text);
    
    if (matches.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          color: isFromMe ? Colors.white : textPrimary,
          fontSize: 14,
        ),
      );
    }
    
    List<TextSpan> spans = [];
    int lastEnd = 0;
    
    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: text.substring(lastEnd, match.start),
          style: TextStyle(color: isFromMe ? Colors.white : textPrimary),
        ));
      }
      
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: isFromMe ? Colors.lightBlueAccent : primaryBlue,
          decoration: TextDecoration.underline,
        ),
        // Add gesture recognizer for tap handling
      ));
      
      lastEnd = match.end;
    }
    
    if (lastEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastEnd),
        style: TextStyle(color: isFromMe ? Colors.white : textPrimary),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  static Widget _buildInteractiveHeader(Map<String, dynamic> header, Map<String, String> fileInfo) {
    final type = header['type'];
    final url = _resolveUrl(fileInfo['filename'] ?? '');
    
    switch (type) {
      case 'image':
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          child: Image.network(url, fit: BoxFit.cover),
        );
      case 'video':
        return Container(
          height: 200,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            color: Colors.black,
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 64, color: Colors.white),
          ),
        );
      case 'document':
        return Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.description, size: 32),
              const SizedBox(width: 8),
              Expanded(child: Text(fileInfo['originalName'] ?? 'Document')),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  static Widget _buildActionButtons(List<dynamic> buttons, bool isFromMe) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: buttons.map<Widget>((button) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: primaryBlue,
                side: const BorderSide(color: primaryBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _handleButtonPress(button),
              child: Text(button['reply']?['title'] ?? 'Button'),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Utility methods
  static Map<String, String> _parseFileInfo(String fileData) {
    if (fileData.isEmpty) return {};
    try {
      final parsed = jsonDecode(fileData);
      return Map<String, String>.from(parsed);
    } catch (e) {
      return {};
    }
  }

  static Map<String, dynamic>? _parseJson(String jsonData) {
    try {
      return jsonDecode(jsonData);
    } catch (e) {
      return null;
    }
  }

  static Map<String, String> _parseVCard(String vcard) {
    final result = <String, String>{};
    final lines = vcard.split('\n');
    
    for (final line in lines) {
      if (line.startsWith('FN:')) {
        result['name'] = line.substring(3);
      } else if (line.startsWith('TEL:')) {
        result['phone'] = line.substring(4);
      }
    }
    
    return result;
  }

  static String _resolveUrl(String filename) {
    if (filename.startsWith('http')) return filename;
    return '/upload/$filename'; // Adjust based on your URL structure
  }

  static IconData _getFileIcon(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.attach_file;
    }
  }

  static void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static void _showImageViewer(String imageUrl) {
    // Implement image viewer
  }

  static void _downloadVCard(String vcard) {
    // Implement vCard download
  }

  static void _handleButtonPress(Map<String, dynamic> button) {
    // Implement button press handling
  }
}