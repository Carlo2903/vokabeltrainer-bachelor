import 'package:flutter/material.dart';

class VocabularyImportPreview extends StatefulWidget {
  final List<Map<String, String>> initialVocabularies;
  final Function(List<Map<String, String>>) onImport;
  final VoidCallback onCancel;

  const VocabularyImportPreview({
    Key? key,
    required this.initialVocabularies,
    required this.onImport,
    required this.onCancel,
  }) : super(key: key);

  @override
  State<VocabularyImportPreview> createState() => _VocabularyImportPreviewState();
}

class _VocabularyImportPreviewState extends State<VocabularyImportPreview> {
  late List<Map<String, String>> _vocabularies;

  @override
  void initState() {
    super.initState();
    // Kopie erstellen, damit wir sie editieren können
    _vocabularies = List.from(widget.initialVocabularies.map((v) => Map<String, String>.from(v)));
  }

  void _editVocab(int index, String field, String newValue) {
    setState(() {
      _vocabularies[index][field] = newValue;
    });
  }

  void _removeVocab(int index) {
    setState(() {
      _vocabularies.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = const Color(0xFF13ec5b);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Import-Vorschau (${_vocabularies.length})',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: widget.onCancel,
              ),
            ],
          ),
        ),
        
        if (_vocabularies.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32.0),
            child: Text('Keine Vokabeln zum Importieren da.'),
          )
        else
          Expanded(
            child: ListView.builder(
              itemCount: _vocabularies.length,
              itemBuilder: (context, index) {
                final vocab = _vocabularies[index];
                return Dismissible(
                  key: ValueKey('${vocab['term']}_$index'),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => _removeVocab(index),
                  background: Container(
                    color: Colors.red.shade400,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: theme.dividerColor.withOpacity(0.1)),
                    ),
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildEditableRow(
                            'Wort:',
                            vocab['term'] ?? '',
                            (val) => _editVocab(index, 'term', val),
                            theme,
                          ),
                          const Divider(height: 16),
                          _buildEditableRow(
                            'Übersetzung:',
                            vocab['translation'] ?? '',
                            (val) => _editVocab(index, 'translation', val),
                            theme,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _vocabularies.isEmpty
                  ? null
                  : () => widget.onImport(_vocabularies),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Importieren',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditableRow(String label, String value, Function(String) onChanged, ThemeData theme) {
    return _EditableRow(
      label: label,
      initialValue: value,
      onChanged: onChanged,
      theme: theme,
    );
  }
}

class _EditableRow extends StatefulWidget {
  final String label;
  final String initialValue;
  final Function(String) onChanged;
  final ThemeData theme;

  const _EditableRow({
    Key? key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    required this.theme,
  }) : super(key: key);

  @override
  State<_EditableRow> createState() => _EditableRowState();
}

class _EditableRowState extends State<_EditableRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(covariant _EditableRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              widget.label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
              fillColor: widget.theme.scaffoldBackgroundColor.withOpacity(0.5),
              filled: true,
            ),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

