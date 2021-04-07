import 'dart:io';

import 'package:cmsc4303_lesson3/controller/firebase_controller.dart';
import 'package:cmsc4303_lesson3/model/constant.dart';
import 'package:cmsc4303_lesson3/model/photo_memo.dart';
import 'package:cmsc4303_lesson3/screen/myview/my_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AddPhotoMemoScreen extends StatefulWidget {
  static const routeName = '/addphotomeno_screen';

  @override
  _AddPhotoMemoScreenState createState() => _AddPhotoMemoScreenState();
}

class _AddPhotoMemoScreenState extends State<AddPhotoMemoScreen> {
  _Controller controller;
  User user = FirebaseAuth.instance.currentUser;
  List<PhotoMemo> photoMemoList;
  GlobalKey<FormState> formKey = GlobalKey();
  File photo;
  String progressMessage;

  @override
  void initState() {
    super.initState();
    controller = _Controller(this);
  }

  void render(fn) => setState(fn);

  @override
  Widget build(BuildContext context) {
    Map args = ModalRoute.of(context).settings.arguments;
    photoMemoList ??= args[Constant.ARG_PHOTOMEMOLIST];
    return Scaffold(
      appBar: AppBar(
        title: Text('Add PhotoMemo'),
        actions: [
          IconButton(icon: Icon(Icons.check), onPressed: controller.save),
        ],
      ),
      body: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: MediaQuery.of(context).size.height * 0.4,
                    child: photo == null
                        ? Icon(Icons.photo_library, size: 300)
                        : Image.file(
                            photo,
                            fit: BoxFit.fill,
                          ),
                  ),
                  Positioned(
                    right: 0.0,
                    bottom: 0.0,
                    child: Container(
                      color: Colors.blue[200],
                      child: PopupMenuButton<String>(
                        onSelected: controller.getPhoto,
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(Icons.photo_camera),
                                Text(Constant.SRC_CAMERA),
                              ],
                            ),
                            value: Constant.SRC_CAMERA,
                          ),
                          PopupMenuItem(
                            child: Row(
                              children: [
                                Icon(Icons.photo_album),
                                Text(Constant.SRC_GALLERY),
                              ],
                            ),
                            value: Constant.SRC_GALLERY,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              progressMessage == null
                  ? SizedBox(
                      height: 1.0,
                    )
                  : Text(
                      progressMessage,
                      style: Theme.of(context).textTheme.headline6,
                    ),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Title',
                ),
                autocorrect: true,
                validator: PhotoMemo.validateTitle,
                onSaved: controller.saveTitle,
              ),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Memo',
                ),
                keyboardType: TextInputType.multiline,
                maxLines: 6,
                autocorrect: true,
                validator: PhotoMemo.validateMemo,
                onSaved: controller.saveMemo,
              ),
              TextFormField(
                decoration: InputDecoration(
                  hintText: 'Shared With (comma separated email list)',
                ),
                keyboardType: TextInputType.emailAddress,
                maxLines: 2,
                validator: PhotoMemo.validateSharedWith,
                onSaved: controller.saveSharedWith,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Controller {
  _AddPhotoMemoScreenState state;

  _Controller(this.state);

  PhotoMemo tempMemo = PhotoMemo();

  void save() async {
    if (!state.formKey.currentState.validate()) return;
    state.formKey.currentState.save();

    MyDialog.circularProgressStart(state.context);

    try {
      Map photoInfo = await FirebaseController.uploadPhotoFile(
        photo: state.photo,
        uid: state.user.uid,
        listener: (double progress) {
          state.render(() {
            if (progress == null)
              state.progressMessage = null;
            else {
              progress *= 100;
              state.progressMessage =
                  'Uploading ' + progress.toStringAsFixed(1) + '%';
            }
          });
        },
      );

      // image labels by ML
      state.render(() => state.progressMessage = 'ML Image Labeler Started!');
      List<dynamic> imageLabels = await FirebaseController.getImageLabels(photoFile: state.photo);
      state.render(() => state.progressMessage = null);

      tempMemo.photoFileName = photoInfo[Constant.ARG_FILE_NAME];
      tempMemo.photoURL = photoInfo[Constant.ARG_DOWNLOAD_URL];
      tempMemo.timestamp = DateTime.now();
      tempMemo.createdBy = state.user.email;
      tempMemo.imageLabels = imageLabels;
      String tempDocId = await FirebaseController.addPhotoMemo(tempMemo);
      tempMemo.docId = tempDocId;
      state.photoMemoList.insert(0, tempMemo);

      MyDialog.circularProgressStop(state.context);

      Navigator.pop(state.context);
    } catch (e) {
      MyDialog.circularProgressStop(state.context);
      MyDialog.info(
        context: state.context,
        title: 'Save PhotoMemo Error',
        content: '$e',
      );
    }
  }

  void saveTitle(String value) {
    tempMemo.title = value;
  }

  void saveMemo(String value) {
    tempMemo.memo = value;
  }

  void saveSharedWith(String value) {
    if (value.trim().length != 0) {
      tempMemo.sharedWith =
          value.split(RegExp('(,| )+')).map((e) => e.trim()).toList();
    }
  }

  void getPhoto(String src) async {
    try {
      PickedFile _imageFile;
      var _picker = ImagePicker();
      if (src == Constant.SRC_CAMERA) {
        _imageFile = await _picker.getImage(source: ImageSource.camera);
      } else {
        _imageFile = await _picker.getImage(source: ImageSource.gallery);
      }
      if (_imageFile == null) return; // cancel when selecting
      state.render(() => state.photo = File(_imageFile.path));
    } catch (e) {
      MyDialog.info(
        context: state.context,
        title: 'Failed to get picture',
        content: '$e',
      );
    }
  }
}
