import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:zemule/providers/user_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.asBottomSheet = false});

  final bool asBottomSheet;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const int _maxProfilePhotoBytes = 5 * 1024 * 1024;
  static const Duration _photoUploadTimeout = Duration(seconds: 20);
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  File? _selectedPhoto;

  @override
  void initState() {
    super.initState();
    final profile = context.read<UserProvider>().user;
    _nameController.text = profile?.name ?? '';
    _emailController.text = profile?.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<UserProvider>();
    final body = Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: widget.asBottomSheet
            ? MediaQuery.of(context).viewInsets.bottom + 20
            : 16,
      ),
      child: Column(
        mainAxisSize: widget.asBottomSheet ? MainAxisSize.min : MainAxisSize.max,
        children: [
          CircleAvatar(
            radius: 38,
            backgroundImage: _selectedPhoto != null ? FileImage(_selectedPhoto!) : null,
            child: _selectedPhoto == null
                ? const Icon(Icons.person_outline, size: 36)
                : null,
          ),
          TextButton.icon(
            onPressed: _pickPhoto,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera / Gallery'),
          ),
          TextField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: provider.isLoading
                      ? null
                      : () async {
                          try {
                            if (_selectedPhoto != null) {
                              await _validateSelectedPhoto(_selectedPhoto!);
                              await provider
                                  .updateProfile(_nameController.text, _selectedPhoto)
                                  .timeout(_photoUploadTimeout);
                            } else {
                              await provider.updateProfile(_nameController.text, _selectedPhoto);
                            }
                            await provider.updateEmail(_emailController.text);
                          } on FormatException catch (error) {
                            debugPrint('EditProfileScreen save FormatException: ${error.message}');
                            _showErrorSafe(error.message);
                            return;
                          } on TimeoutException catch (error, stackTrace) {
                            debugPrint('EditProfileScreen save timeout: $error');
                            debugPrint('EditProfileScreen save timeout stackTrace: $stackTrace');
                            _showErrorSafe('Timeout error');
                            return;
                          } on FileSystemException catch (error, stackTrace) {
                            debugPrint('EditProfileScreen file error: $error');
                            debugPrint('EditProfileScreen file error stackTrace: $stackTrace');
                            _showErrorSafe('Something went wrong. Please try again');
                            return;
                          } catch (error, stackTrace) {
                            debugPrint('EditProfileScreen save failed: $error');
                            debugPrint('EditProfileScreen save stackTrace: $stackTrace');
                            _showErrorSafe('Something went wrong. Please try again');
                            return;
                          }
                          if (!mounted) {
                            return;
                          }
                          Navigator.of(this.context).pop();
                        },
                  child: provider.isLoading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (widget.asBottomSheet) {
      return SingleChildScrollView(child: body);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(child: body),
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take photo'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 70,
                      maxWidth: 1440,
                      maxHeight: 1440,
                    );
                    if (picked == null || !mounted) {
                      return;
                    }
                    final file = File(picked.path);
                    final size = await file.length();
                    if (!mounted) {
                      return;
                    }
                    if (size > _maxProfilePhotoBytes) {
                      _showErrorSafe('Upload failed. Please try again with a smaller image');
                      return;
                    }
                    setState(() => _selectedPhoto = file);
                  } on PlatformException {
                    _showErrorSafe('Unable to access camera. Check camera permission and try again.');
                  } catch (_) {
                    _showErrorSafe('Failed to capture photo. Please try again.');
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final picked = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                      maxWidth: 1440,
                      maxHeight: 1440,
                    );
                    if (picked == null || !mounted) {
                      return;
                    }
                    final file = File(picked.path);
                    final size = await file.length();
                    if (!mounted) {
                      return;
                    }
                    if (size > _maxProfilePhotoBytes) {
                      _showErrorSafe('Upload failed. Please try again with a smaller image');
                      return;
                    }
                    setState(() => _selectedPhoto = file);
                  } on PlatformException {
                    _showErrorSafe('Unable to access gallery. Check photos permission and try again.');
                  } catch (_) {
                    _showErrorSafe('Failed to select photo. Please try again.');
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showErrorSafe(String message) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('EditProfileScreen snack error: $message');
      return;
    }
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _validateSelectedPhoto(File file) async {
    final exists = await file.exists();
    if (!exists) {
      throw const FormatException('Something went wrong. Please try again');
    }

    final size = await file.length();
    if (size <= 0) {
      throw const FormatException('Something went wrong. Please try again');
    }
    if (size > _maxProfilePhotoBytes) {
      throw const FormatException('Upload failed. Please try again with a smaller image');
    }

    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        throw const FormatException('Something went wrong. Please try again');
      }

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      frame.image.dispose();
      codec.dispose();
    } on FormatException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('EditProfileScreen image validation failed: $error');
      debugPrint('EditProfileScreen image validation stackTrace: $stackTrace');
      throw const FormatException('Upload failed. Please select a valid image');
    }
  }
}
