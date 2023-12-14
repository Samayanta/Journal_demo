import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.deepPurpleAccent,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          color: Colors.deepPurpleAccent,
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          color: Colors.black,
        ),
      ),
      themeMode: ThemeMode.light,
      home: MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String searchText = '';
  LocalAuthentication _localAuthentication = LocalAuthentication();
  bool isAuthenticated = false;
  bool isDarkMode = false;
  int? editingIndex;
  List<Map<String, dynamic>> journalEntries = [];

  @override
  void initState() {
    super.initState();
    _checkBiometrics(); // Check if biometrics is available
    _authenticate(); // Authenticate the user when opening
    _loadEntries(); // Load saved entries when the app starts
  }

  Future<void> _checkBiometrics() async {
    bool hasBiometrics = await _localAuthentication.canCheckBiometrics;
    setState(() {
      isAuthenticated = hasBiometrics;
    });
  }

  Future<void> _authenticate() async {
    try {
      bool authenticated = await _localAuthentication.authenticate(
        localizedReason: 'Authenticate to access the app',
        // Add the following line if you want to use an error dialog
        // useErrorDialogs: false,
      );

      setState(() {
        isAuthenticated = authenticated;
      });
    } catch (e) {
      print('Error during biometric authentication: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: isAuthenticated,
      child: _buildAuthenticatedContent(),
      replacement: _buildAuthenticationRequiredScreen(),
    );
  }

  Widget _buildAuthenticatedContent() {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          SettingsPage(isDarkMode: isDarkMode)),
                );
              },
              child: Icon(
                Icons.settings,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(width: 8.0),
            Text(
              "My Journal",
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.deepPurpleAccent,
        actions: [
          IconButton(
            icon: Icon(Icons.search,
                color: isDarkMode ? Colors.white : Colors.black),
            onPressed: () {
              _showSearchBar();
            },
          ),
          Switch(
            value: isDarkMode,
            onChanged: (value) {
              setState(() {
                isDarkMode = value;
              });
            },
          ),
        ],
      ),
      body: Material(
        color: isDarkMode ? Colors.grey[900] : Colors.white,
        child: ListView(
          children: [
            Container(
              height: height * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  children: List.generate(
                    journalEntries.length,
                    (index) => InkWell(
                      onTap: () {
                        _startEditing(index);
                      },
                      child: Container(
                        height: 220.0,
                        child: Expanded(
                          child: Container(
                            margin: EdgeInsets.all(8.0),
                            padding: EdgeInsets.all(12.0),
                            decoration: BoxDecoration(
                              color:
                                  isDarkMode ? Colors.grey[800] : Colors.white,
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  journalEntries[index]['title'] ?? '',
                                  style: TextStyle(
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    fontSize: 18.0,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                Flexible(
                                  child: Text(
                                    journalEntries[index]['text'] ?? '',
                                    style: TextStyle(
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 8.0),
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 8.0,
                                  children: List.generate(
                                    (journalEntries[index]['images']
                                            as List<File>)
                                        .length,
                                    (imageIndex) => Image.file(
                                      (journalEntries[index]['images']
                                          as List<File>)[imageIndex],
                                      width: 80.0,
                                      height: 80.0,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final entry = {
            'title': 'New Entry ${journalEntries.length + 1}',
            'text': 'This is a new journal entry.',
            'images': <File>[],
          };
          final image = await _pickImage();
          if (image != null) {
            setState(() {
              (entry['images'] as List<File>).add(image);
            });
          }
          setState(() {
            journalEntries.add(entry);
          });
          // Save entries after adding a new one
          _saveEntries();
        },
        child: Icon(
          Icons.add,
          color: isDarkMode ? Colors.black : Colors.white,
        ),
        backgroundColor:
            isDarkMode ? Colors.deepPurpleAccent : Colors.grey[900],
      ),
    );
  }

  Widget _buildAuthenticationRequiredScreen() {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            _authenticate(); // Trigger authentication when the button is pressed
          },
          child: Text('Authenticate to unlock'),
        ),
      ),
    );
  }

  void _showSearchBar() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Search"),
          content: TextField(
            onChanged: (value) {
              setState(() {
                searchText = value;
              });
            },
            decoration: InputDecoration(
              hintText: "Enter title to search...",
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                // Perform search logic based on the searchText
                _performSearch();
                Navigator.of(context).pop();
              },
              child: Text("Search"),
            ),
          ],
        );
      },
    );
  }

  void _performSearch() {
    List<Map<String, dynamic>> searchResults = [];

    // Filter journalEntries based on the searchText
    for (var entry in journalEntries) {
      if ((entry['title'] as String)
          .toLowerCase()
          .contains(searchText.toLowerCase())) {
        searchResults.add(entry);
      }
    }

    // Update the displayed entries accordingly
    setState(() {
      journalEntries = searchResults;
    });

    // For simplicity, let's print the search results
    print("Search results for: $searchText");
  }

  void _startEditing(int index) {
    setState(() {
      editingIndex = index;
    });

    _authenticate(); // Authenticate the user when editing a journal entry
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EntryDetailPage(
          entry: journalEntries[index],
          isDarkMode: isDarkMode,
          onDelete: () {
            // Handle delete action if needed
            setState(() {
              journalEntries.removeAt(index);
              editingIndex = null;
            });
            _saveEntries();
            Navigator.pop(context);
          },
          onSave: () {
            // Save the edited entry
            _saveEntries();
          },
        ),
      ),
    );
  }

  Future<File?> _pickImage() async {
    final imagePicker = ImagePicker();
    try {
      final pickedFile =
          await imagePicker.pickImage(source: ImageSource.gallery);
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      // Handle image pick failure
      print('Error picking image: $e');
      return null;
    }
  }

  Future<bool> _confirmDelete(int index) async {
    return (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text("Confirm Delete"),
              content: Text("Are you sure you want to delete this entry?"),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text("Cancel"),
                ),
                TextButton(
                  onPressed: () {
                    // Remove the entry and save entries
                    setState(() {
                      journalEntries.removeAt(index);
                    });
                    _saveEntries();
                    Navigator.of(context).pop(); // Close the dialog
                  },
                  child: Text("Delete"),
                ),
              ],
            );
          },
        )) ??
        false;
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save titles and texts
      await prefs.setStringList(
        'journal_titles',
        journalEntries
            .map<String>((entry) => entry['title'] as String)
            .toList(),
      );
      await prefs.setStringList(
        'journal_texts',
        journalEntries.map<String>((entry) => entry['text'] as String).toList(),
      );

      // Save images
      for (int i = 0; i < journalEntries.length; i++) {
        final entry = journalEntries[i];
        await prefs.setStringList(
          'journal_images_$i',
          (entry['images'] as List<File>).map((image) => image.path).toList(),
        );
      }
    } catch (e) {
      print('Error saving entries: $e');
    }
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final titles = prefs.getStringList('journal_titles');
      final texts = prefs.getStringList('journal_texts');

      // Load images
      List<Map<String, dynamic>> loadedEntries = [];
      for (int i = 0;; i++) {
        final images = prefs.getStringList('journal_images_$i');
        if (images == null) {
          break;
        }

        loadedEntries.add({
          'title': titles![i],
          'text': texts![i],
          'images': images.map((path) => File(path)).toList(),
        });
      }

      setState(() {
        journalEntries = loadedEntries;
      });
    } catch (e) {
      print('Error loading entries: $e');
    }
  }

  Map<String, dynamic> entryToJson(Map<String, dynamic> entry) {
    return {
      'title': entry['title'],
      'text': entry['text'],
      'images':
          (entry['images'] as List<File>).map((image) => image.path).toList(),
    };
  }

  Map<String, dynamic> entryFromJson(String entryJson) {
    final entryMap = Map<String, dynamic>.from(json.decode(entryJson));
    final images =
        (entryMap['images'] as List<String>).map((path) => File(path)).toList();
    entryMap['images'] = images;
    return entryMap;
  }
}

class EntryDetailPage extends StatefulWidget {
  final Map<String, dynamic> entry;
  final bool isDarkMode;
  final VoidCallback onDelete;
  final VoidCallback onSave;

  EntryDetailPage({
    required this.entry,
    required this.isDarkMode,
    required this.onDelete,
    required this.onSave,
  });

  @override
  _EntryDetailPageState createState() => _EntryDetailPageState();
}

class _EntryDetailPageState extends State<EntryDetailPage> {
  late TextEditingController titleController;
  late TextEditingController textController;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.entry['title']);
    textController = TextEditingController(text: widget.entry['text']);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    double height = MediaQuery.of(context).size.height;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit Entry",
          style: TextStyle(
            color: widget.isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor:
            widget.isDarkMode ? Colors.black : Colors.deepPurpleAccent,
        actions: [
          IconButton(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            onPressed: () {
              // Save changes and pop the page
              setState(() {
                widget.entry['title'] = titleController.text;
                widget.entry['text'] = textController.text;
                widget.onSave();
              });
              setState(() {});
              Navigator.pop(context);
            },
            icon: Icon(
              Icons.save,
              color: widget.isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          IconButton(
            color: widget.isDarkMode ? Colors.white : Colors.black,
            onPressed: () {
              // Delete the entry and pop the page
              widget.onDelete();
            },
            icon: Icon(
              Icons.delete,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Container(
          color: widget.isDarkMode ? Colors.black : Colors.white,
          width: width,
          height: height,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Title",
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: titleController,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    SizedBox(height: 16.0),
                    Text(
                      "Text",
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                        fontSize: 18.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextField(
                      controller: textController,
                      style: TextStyle(
                        color: widget.isDarkMode ? Colors.white : Colors.black,
                      ),
                      maxLines: 10,
                    ),
                    SizedBox(height: 16.0),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () async {
                            // Pick an image and add it to the entry
                            final image = await _pickImage();
                            if (image != null) {
                              setState(() {
                                (widget.entry['images'] as List<File>)
                                    .add(image);
                              });
                            }
                          },
                          child: Text("Add Image"),
                          style: ElevatedButton.styleFrom(
                            primary:
                                widget.isDarkMode ? Colors.white : Colors.black,
                            onPrimary:
                                widget.isDarkMode ? Colors.black : Colors.white,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: List.generate(
                        (widget.entry['images'] as List<File>).length,
                        (imageIndex) => Image.file(
                          (widget.entry['images'] as List<File>)[imageIndex],
                          width: 80.0,
                          height: 80.0,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<File?> _pickImage() async {
    final imagePicker = ImagePicker();
    try {
      final pickedFile =
          await imagePicker.pickImage(source: ImageSource.gallery);
      return pickedFile != null ? File(pickedFile.path) : null;
    } catch (e) {
      // Handle image pick failure
      print('Error picking image: $e');
      return null;
    }
  }
}

class SettingsPage extends StatelessWidget {
  final bool isDarkMode;

  const SettingsPage({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.deepPurpleAccent,
      ),
      body: SettingsList(isDarkMode: isDarkMode),
    );
  }
}

// Update the SettingsList widget
class SettingsList extends StatefulWidget {
  final bool isDarkMode;

  const SettingsList({Key? key, required this.isDarkMode}) : super(key: key);

  @override
  _SettingsListState createState() => _SettingsListState();
}

class _SettingsListState extends State<SettingsList> {
  bool biometricsEnabled =
      false; // Default value, you can change this based on your logic

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        ListTile(
          leading: Icon(
            Icons.fingerprint,
            color: widget.isDarkMode ? Colors.black : Colors.white,
          ),
          title: Text(
            "Biometrics",
            style: TextStyle(
              color: widget.isDarkMode ? Colors.black : Colors.white,
            ),
          ),
          trailing: Switch(
            value: biometricsEnabled,
            onChanged: (value) {
              setState(() {
                biometricsEnabled = value;
                // Add your logic for handling the toggle change
              });
            },
            activeColor:
                widget.isDarkMode ? Colors.deepPurpleAccent : Colors.deepPurple,
          ),
          onTap: () {
            // Add additional functionality for tapping on the Biometrics list item
            // This can be used to navigate to a dedicated Biometrics settings page, for example.
          },
        ),
        // Add more settings items as needed
      ],
    );
  }
}
