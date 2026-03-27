part of 'main.dart';

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({
    required this.sessionPlan,
    required this.reviewMode,
    required this.selectedCollection,
    required this.progress,
    required this.collectionItems,
    required this.recommendedCollection,
    required this.onSessionPlanSelected,
    required this.onReviewModeSelected,
    required this.onCollectionSelected,
    required this.onCollectionItemsChanged,
    required this.onExportJsonData,
    required this.onImportJsonData,
    required this.loadAutomaticBackupsEnabled,
    required this.onAutomaticBackupsEnabledChanged,
    required this.onListAutomaticBackups,
    required this.onRestoreAutomaticBackup,
  });

  final SessionPlan sessionPlan;
  final ReviewMode reviewMode;
  final PracticeCollection selectedCollection;
  final Map<PracticeCollection, List<LetterProgress>> progress;
  final Map<PracticeCollection, List<String>> collectionItems;
  final PracticeCollection recommendedCollection;
  final ValueChanged<SessionPlan> onSessionPlanSelected;
  final ValueChanged<ReviewMode> onReviewModeSelected;
  final ValueChanged<PracticeCollection> onCollectionSelected;
  final Future<void> Function(PracticeCollection collection, List<String> items)
  onCollectionItemsChanged;
  final Future<String?> Function() onExportJsonData;
  final Future<String?> Function(String rawJson) onImportJsonData;
  final Future<bool> Function() loadAutomaticBackupsEnabled;
  final Future<String?> Function(bool enabled) onAutomaticBackupsEnabledChanged;
  final Future<List<LearnToReadBackupEntry>> Function() onListAutomaticBackups;
  final Future<String?> Function(String backupId) onRestoreAutomaticBackup;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  static final Uri _changelogUri = Uri.parse(kAppChangelogUrl);
  late Map<PracticeCollection, List<String>> _localCollectionItems;
  bool _automaticBackupsEnabled = false;
  bool _isLoadingAutomaticBackupPreference = false;
  String? _backupActionMessage;

  @override
  void initState() {
    super.initState();
    _localCollectionItems = <PracticeCollection, List<String>>{
      for (final entry in widget.collectionItems.entries)
        entry.key: List<String>.from(entry.value),
    };
    _loadAutomaticBackupPreference();
  }

  Future<void> _loadAutomaticBackupPreference() async {
    setState(() {
      _isLoadingAutomaticBackupPreference = true;
    });
    final bool enabled = await widget.loadAutomaticBackupsEnabled();
    if (!mounted) {
      return;
    }
    setState(() {
      _automaticBackupsEnabled = enabled;
      _isLoadingAutomaticBackupPreference = false;
    });
  }

  Future<void> _promptAddWord(PracticeCollection collection) async {
    final TextEditingController controller = TextEditingController();
    final String? added = await showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        final int targetLength = collection == PracticeCollection.twoLetterWords
            ? 2
            : 3;

        return AlertDialog(
          title: Text('Add ${collection.title.toLowerCase()}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.none,
            decoration: InputDecoration(labelText: '$targetLength-letter word'),
            onSubmitted: (String value) =>
                Navigator.of(dialogContext).pop(value),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );

    if (added == null) {
      return;
    }

    final List<String> currentItems = _localCollectionItems[collection]!;
    final List<String> nextItems = _sanitizeCollectionItems(
      collection,
      <String>[...currentItems, added],
    );
    if (nextItems.length == currentItems.length) {
      final int length = collection == PracticeCollection.twoLetterWords
          ? 2
          : 3;
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Add a unique $length-letter word.')),
      );
      return;
    }

    setState(() {
      _localCollectionItems[collection] = nextItems;
    });
    await widget.onCollectionItemsChanged(collection, nextItems);
  }

  Future<void> _removeWord(PracticeCollection collection, String item) async {
    final List<String> currentItems = _localCollectionItems[collection]!;
    if (currentItems.length <= 1) {
      return;
    }

    final List<String> nextItems = List<String>.from(currentItems)
      ..remove(item);
    setState(() {
      _localCollectionItems[collection] = nextItems;
    });
    await widget.onCollectionItemsChanged(collection, nextItems);
  }

  Future<void> _openChangelog() async {
    final bool didLaunch = await launchUrl(
      _changelogUri,
      mode: LaunchMode.externalApplication,
    );
    if (!didLaunch && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open changelog.')),
      );
    }
  }

  Future<void> _showJsonExportDialog() async {
    final String? exportJson = await widget.onExportJsonData();
    if (!mounted || exportJson == null) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Export JSON',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: SingleChildScrollView(
                    child: SelectableText(exportJson),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: exportJson),
                        );
                        if (!mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('JSON copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showJsonImportDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? rawJson = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.of(bottomSheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Import JSON',
                  style: Theme.of(bottomSheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  minLines: 8,
                  maxLines: 14,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '{\n  "schemaVersion": 1,\n  ...\n}',
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    FilledButton(
                      onPressed: () =>
                          Navigator.of(bottomSheetContext).pop(controller.text),
                      child: const Text('Import'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.of(bottomSheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (rawJson == null || rawJson.trim().isEmpty || !mounted) {
      return;
    }

    final bool? shouldImport = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Import JSON'),
          content: const Text(
            'Replace the current progress and editable word lists with this JSON snapshot?',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    if (shouldImport != true || !mounted) {
      return;
    }

    final String? result = await widget.onImportJsonData(rawJson);
    if (!mounted) {
      return;
    }
    setState(() {
      _backupActionMessage = result;
    });
  }

  Future<void> _toggleAutomaticBackups(bool enabled) async {
    setState(() {
      _automaticBackupsEnabled = enabled;
      _backupActionMessage = null;
    });
    final String? result = await widget.onAutomaticBackupsEnabledChanged(
      enabled,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _backupActionMessage = result;
    });
  }

  String _backupTimeLabel(BuildContext context, DateTime savedAt) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    return '${localizations.formatFullDate(savedAt)} at '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(savedAt))}';
  }

  Future<void> _restoreAutomaticBackup() async {
    final List<LearnToReadBackupEntry> backups = await widget
        .onListAutomaticBackups();
    if (!mounted) {
      return;
    }

    if (backups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No automatic backups are available yet.'),
        ),
      );
      return;
    }

    final LearnToReadBackupEntry? selectedBackup =
        await showModalBottomSheet<LearnToReadBackupEntry>(
          context: context,
          builder: (BuildContext bottomSheetContext) {
            return SafeArea(
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  const ListTile(
                    title: Text(
                      'Restore Automatic Backup',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('Choose a recent local JSON snapshot'),
                  ),
                  const Divider(height: 1),
                  for (final LearnToReadBackupEntry backup in backups)
                    ListTile(
                      leading: const Icon(Icons.history_outlined),
                      title: Text(
                        _backupTimeLabel(bottomSheetContext, backup.savedAt),
                      ),
                      subtitle: Text(backup.fileName),
                      onTap: () => Navigator.of(bottomSheetContext).pop(backup),
                    ),
                ],
              ),
            );
          },
        );

    if (!mounted || selectedBackup == null) {
      return;
    }

    final bool? shouldRestore = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Restore backup'),
          content: Text(
            'Restore "${selectedBackup.fileName}"? This replaces the current local data.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Restore'),
            ),
          ],
        );
      },
    );

    if (shouldRestore != true || !mounted) {
      return;
    }

    final String? result = await widget.onRestoreAutomaticBackup(
      selectedBackup.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _backupActionMessage = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: ListView(
            children: <Widget>[
              Text(
                'Keep the practice screen simple and move setup here.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              _RecommendationBanner(collection: widget.recommendedCollection),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Session length',
                child: _SessionPlanPicker(
                  sessionPlan: widget.sessionPlan,
                  onSelected: widget.onSessionPlanSelected,
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Practice mode',
                child: _ReviewModePicker(
                  reviewMode: widget.reviewMode,
                  onSelected: widget.onReviewModeSelected,
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Choose set',
                child: _CollectionPicker(
                  selectedCollection: widget.selectedCollection,
                  onSelected: widget.onCollectionSelected,
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Data backup',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (_backupActionMessage != null) ...<Widget>[
                      Text(_backupActionMessage!),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.tonalIcon(
                          onPressed: _showJsonExportDialog,
                          icon: const Icon(Icons.upload_file_outlined),
                          label: const Text('Export JSON'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _showJsonImportDialog,
                          icon: const Icon(Icons.download_outlined),
                          label: const Text('Import JSON'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Automatic JSON backups'),
                      subtitle: const Text(
                        'Keep up to 20 recent local snapshots and update them automatically',
                      ),
                      value: _automaticBackupsEnabled,
                      onChanged: _isLoadingAutomaticBackupPreference
                          ? null
                          : _toggleAutomaticBackups,
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.restore_outlined),
                      title: const Text('Restore from automatic backup'),
                      subtitle: const Text(
                        'Choose one of the recent local snapshots and replace current data',
                      ),
                      onTap: _restoreAutomaticBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Parent overview',
                child: Column(
                  children: PracticeCollection.values.map((
                    PracticeCollection collection,
                  ) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: collection == PracticeCollection.values.last
                            ? 0
                            : 12,
                      ),
                      child: _CollectionOverviewCard(
                        snapshot: _buildSnapshot(
                          collection,
                          widget.progress,
                          _localCollectionItems,
                        ),
                        isRecommended:
                            collection == widget.recommendedCollection,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Word lists',
                child: Column(
                  children: PracticeCollection.values
                      .where(
                        (PracticeCollection collection) =>
                            collection.isEditableWordSet,
                      )
                      .map((PracticeCollection collection) {
                        return Padding(
                          padding: EdgeInsets.only(
                            bottom:
                                collection ==
                                    PracticeCollection.threeLetterWords
                                ? 0
                                : 16,
                          ),
                          child: _EditableWordListCard(
                            collection: collection,
                            items: _localCollectionItems[collection]!,
                            onAddWord: () => _promptAddWord(collection),
                            onRemoveWord: (String item) =>
                                _removeWord(collection, item),
                          ),
                        );
                      })
                      .toList(),
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'Cloud sync groundwork',
                child: Text(
                  SupabaseBootstrap.isConfigured
                      ? 'Supabase is configured for this build. Account and sync flows can be layered on top of this bootstrap next.'
                      : 'Supabase is not configured in this build yet. Launch with SUPABASE_URL and SUPABASE_ANON_KEY to enable the bootstrap later.',
                ),
              ),
              const SizedBox(height: 20),
              _SettingsSection(
                title: 'App version',
                child: _VersionBadge(
                  version: kAppVersionLabel,
                  onTap: _openChangelog,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version, required this.onTap});

  final String version;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Open changelog',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                version,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.open_in_new,
                size: 14,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _CollectionPicker extends StatelessWidget {
  const _CollectionPicker({
    required this.selectedCollection,
    required this.onSelected,
  });

  final PracticeCollection selectedCollection;
  final ValueChanged<PracticeCollection> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: PracticeCollection.values.map((PracticeCollection collection) {
        final bool isSelected = collection == selectedCollection;
        return ChoiceChip(
          label: Text(collection.label),
          selected: isSelected,
          onSelected: (_) => onSelected(collection),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF12343B),
          backgroundColor: const Color(0xFFE9E0D0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _SessionPlanPicker extends StatelessWidget {
  const _SessionPlanPicker({
    required this.sessionPlan,
    required this.onSelected,
  });

  final SessionPlan sessionPlan;
  final ValueChanged<SessionPlan> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SessionPlan.values.map((SessionPlan plan) {
        final bool isSelected = plan == sessionPlan;
        return ChoiceChip(
          label: Text(plan.label),
          selected: isSelected,
          onSelected: (_) => onSelected(plan),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF5B7C6D),
          backgroundColor: const Color(0xFFF1E6D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _ReviewModePicker extends StatelessWidget {
  const _ReviewModePicker({required this.reviewMode, required this.onSelected});

  final ReviewMode reviewMode;
  final ValueChanged<ReviewMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ReviewMode.values.map((ReviewMode mode) {
        final bool isSelected = mode == reviewMode;
        return ChoiceChip(
          label: Text(mode.label),
          selected: isSelected,
          onSelected: (_) => onSelected(mode),
          labelStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF12343B),
          ),
          selectedColor: const Color(0xFF7A5C3E),
          backgroundColor: const Color(0xFFF1E6D6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        );
      }).toList(),
    );
  }
}

class _RecommendationBanner extends StatelessWidget {
  const _RecommendationBanner({required this.collection});

  final PracticeCollection collection;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFE3EFE9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: <Widget>[
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF12343B)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Recommended next: ${collection.title}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF12343B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CollectionOverviewCard extends StatelessWidget {
  const _CollectionOverviewCard({
    required this.snapshot,
    required this.isRecommended,
  });

  final CollectionSnapshot snapshot;
  final bool isRecommended;

  @override
  Widget build(BuildContext context) {
    final int total = snapshot.totalCount;
    final String statusText = switch ((
      snapshot.isUnlocked,
      snapshot.isMastered,
    )) {
      (false, _) => 'Locked until earlier set is stable',
      (true, true) => 'Stable and ready to keep or move on',
      (true, false) =>
        snapshot.dueCount > 0 ? '${snapshot.dueCount} due now' : 'In progress',
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isRecommended
              ? const Color(0xFF5B7C6D)
              : const Color(0xFFE0D6C6),
          width: isRecommended ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    snapshot.collection.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (isRecommended)
                  const _InfoChip(label: 'Next up', color: Color(0xFFD7F1EC)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF4E5D52)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  label: 'Known ${snapshot.knownCount}/$total',
                  color: const Color(0xFFD7F1EC),
                ),
                _InfoChip(
                  label: 'Seen ${snapshot.seenCount}/$total',
                  color: const Color(0xFFE8F1E7),
                ),
                _InfoChip(
                  label: 'Due ${snapshot.dueCount}',
                  color: const Color(0xFFFFE2C7),
                ),
                _InfoChip(
                  label: 'Weak ${snapshot.weakCount}',
                  color: const Color(0xFFF8D9D9),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditableWordListCard extends StatelessWidget {
  const _EditableWordListCard({
    required this.collection,
    required this.items,
    required this.onAddWord,
    required this.onRemoveWord,
  });

  final PracticeCollection collection;
  final List<String> items;
  final VoidCallback onAddWord;
  final ValueChanged<String> onRemoveWord;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0D6C6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    collection.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: Key('add-word-${collection.id}'),
                  onPressed: onAddWord,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items.map((String item) {
                final bool canRemove = items.length > 1;
                return InputChip(
                  key: Key('${collection.id}-$item'),
                  label: Text(item),
                  onDeleted: canRemove ? () => onRemoveWord(item) : null,
                  deleteIcon: const Icon(Icons.close_rounded, size: 18),
                  backgroundColor: const Color(0xFFF3ECE1),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
