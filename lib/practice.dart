import 'dart:typed_data';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:capstone_project_intune/pitch_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_audio_capture/flutter_audio_capture.dart';
import 'package:pitchupdart/instrument_type.dart';
import 'package:pitchupdart/pitch_handler.dart';
import 'package:xml/xml.dart';
import 'package:capstone_project_intune/musicXML/parser.dart';
import 'package:capstone_project_intune/musicXML/data.dart';
import 'package:capstone_project_intune/notes/music-line.dart';
import 'package:capstone_project_intune/main.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

Future<Score> loadXML() async {
  final rawFile = await rootBundle.loadString('hanon-no1.musicxml');
  final result = parseMusicXML(XmlDocument.parse(rawFile));
  return result;
}

const double STAFF_HEIGHT = 36;


class Practice extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Intonation Practice',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
      debugShowCheckedModeBanner: false, //setup this property
    );
  }
}
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _audioRecorder = FlutterAudioCapture();
  final pitchDetectorDart = PitchDetector(44100, 2000);
  final pitchupDart = PitchHandler(InstrumentType.guitar);

  var note = "";
  var notePicked = "";
  var noteStatus = "";
  var status = "Click on start";

  final storage = FirebaseStorage.instance; // Create instance of Firebase Storage
  final storageRef = FirebaseStorage.instance.ref(); // Create a reference of storage

  // final filesRef = storageRef.child("MusicXMLFiles");


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery
        .of(context)
        .size;

    return Scaffold(
      drawer: const SideDrawer(),
      appBar: AppBar(
        title: const Text('Intonation Practice'),
      ),
      body: Center(
          child: Column(children: [
            Center(
              child: Container(
                alignment: Alignment.center,
                //width: size.width - 40,
                //height: size.height - 20,
                child: FutureBuilder<Score>(
                    future: loadXML(),
                    builder: (context, snapshot) {
                      if (snapshot.hasData) {
                        return MusicLine(
                          options: MusicLineOptions(
                            snapshot.data!,
                            STAFF_HEIGHT,
                            1,
                          ),
                        );
                      } else if (snapshot.hasError) {
                        return Text('Oh, this failed!\n${snapshot.error}');
                      } else {
                        return const SizedBox(
                          width: 60,
                          height: 40,
                          child: CircularProgressIndicator(),
                        );
                      }
                    }
                ),
              ),
            ),
            Expanded(
                child: Row(
                  children: [
                    Expanded(
                        child: Center(
                            child: FloatingActionButton(
                                heroTag: "Start",
                                backgroundColor: Colors.green,
                                splashColor: Colors.blueGrey,
                                onPressed: _startCapture,
                                child: const Text("Start")))),
                    Expanded(
                        child: Center(
                            child: FloatingActionButton(
                                heroTag: "Stop",
                                backgroundColor: Colors.red,
                                splashColor: Colors.blueGrey,
                                onPressed: _stopCapture,
                                child: const Text("Stop")))),
                    Expanded(
                        child: Center(
                            child: FloatingActionButton(
                                heroTag: "Upload",
                                backgroundColor: Colors.grey,
                                splashColor: Colors.white,
                                onPressed: _pickFile,
                                child: const Text("Upload")))),
                  ],
                ))
          ],
          )
      ),
    );
  }


  Future<void> _startCapture() async {
    await _audioRecorder.start(listener, onError,
        sampleRate: 44100, bufferSize: 3000);

    setState(() {
      note = "";
      status = "Play something";
    });
  }

  Future<void> _stopCapture() async {
    await _audioRecorder.stop();

    setState(() {
      note = "";
      status = "Click on start";
    });
  }

  void _pickFile() async{

    // opens storage to pick files and the picked file or files
    final result = await FilePicker.platform.pickFiles(allowMultiple: false);

    // if no file is picked
    if (result == null) return;

    // print(result.files.first.name);
    // print(result.files.first.size);
    // print(result.files.first.path);

    // Create reference to folder in which to save the Files
    // Cannot save in root of storage bucket, must save in child URL
    final filesRef = storageRef.child("MusicXMLFiles");

    // Get the PlatformFile that was chosen and its path and name(unnecessary? it was glitching)
    var fileFile = result.files.first;
    var filePath = fileFile.path;
    var fileName = fileFile.name;

    // handle null safety of String? to String
    if (filePath == null)
    {
        return;
    }
    else
    {
      // Create File to be stored and store file
      var fileForFirebase = File(filePath);

      // final refVar = filesRef

      filesRef.child(fileName).putFile(fileForFirebase);
    }
  }

  void listener(dynamic obj) {
    //Gets the audio sample
    var buffer = Float64List.fromList(obj.cast<double>());
    final List<double> audioSample = buffer.toList();

    //Uses pitch_detector_dart library to detect a pitch from the audio sample
    final result = pitchDetectorDart.getPitch(audioSample);

    //If there is a pitch - evaluate it
    if (result.pitched) {
      //Uses the pitchupDart library to check a given pitch for a Guitar
      final handledPitchResult = pitchupDart.handlePitch(result.pitch);
      status = handledPitchResult.tuningStatus.toString();

      //Updates the state with the result
      setState(() {
        if (status == "TuningStatus.tuned") {
          status = "Tuned!!!!".toUpperCase();
          _stopCaptureTuned();
        }
      });
    }
  }

  Future<void> _stopCaptureTuned() async {
    await _audioRecorder.stop();

    setState(() {
      note = "";
      //status = "Tuned!!!!";
    });
  }

  void onError(Object e) {
    print(e);
  }
}