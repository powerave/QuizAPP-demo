import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/profile_provider.dart';

class ProfileEntryPage extends ConsumerStatefulWidget {
  const ProfileEntryPage({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  ConsumerState<ProfileEntryPage> createState() => _ProfileEntryPageState();
}

class _ProfileEntryPageState extends ConsumerState<ProfileEntryPage> {
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();
  bool createAccount = true;
  String? error;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    nameController.text = ref.read(profileProvider).displayName;
    usernameController.text = ref.read(profileProvider).username;
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.bolt,
                  size: 42,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 28),
                Text(
                  'Bienvenue sur QuizAPP',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  createAccount
                      ? 'Crée ton compte pour conserver ton profil et ton historique.'
                      : 'Connecte-toi pour retrouver ton profil et ton historique.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Créer un compte')),
                    ButtonSegment(value: false, label: Text('Se connecter')),
                  ],
                  selected: {createAccount},
                  onSelectionChanged: (selection) {
                    setState(() {
                      createAccount = selection.single;
                      error = null;
                    });
                  },
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: usernameController,
                  textInputAction: TextInputAction.next,
                  maxLength: 24,
                  decoration: const InputDecoration(
                    labelText: 'Nom d’utilisateur',
                    hintText: 'Ex. nova42',
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  textInputAction: createAccount
                      ? TextInputAction.next
                      : TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Mot de passe',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
                if (createAccount) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    textInputAction: TextInputAction.done,
                    maxLength: 20,
                    decoration: const InputDecoration(
                      labelText: 'Nom d’affichage',
                      hintText: 'Ex. Nova',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                const SizedBox(height: 12),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: isSaving ? null : _submit,
                    icon: isSaving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(isSaving
                      ? 'Connexion...'
                      : createAccount
                        ? 'Créer mon compte'
                        : 'Se connecter'),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                    createAccount
                      ? 'Le nom d’affichage doit être unique dans l’application.'
                      : 'Ton mot de passe reste utilisé uniquement pour la connexion.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final name = nameController.text.trim();
    if (username.length < 3) {
      setState(() => error = 'Le nom d’utilisateur doit contenir au moins 3 caractères.');
      return;
    }
    if (password.length < 8) {
      setState(() => error = 'Le mot de passe doit contenir au moins 8 caractères.');
      return;
    }
    if (createAccount && name.length < 2) {
      setState(() => error = 'Le nom d’affichage doit contenir au moins 2 caractères.');
      return;
    }
    setState(() {
      error = null;
      isSaving = true;
    });
    try {
      await ref.read(profileProvider.notifier).authenticate(
            username: username,
            password: password,
            displayName: name,
            createAccount: createAccount,
          );
    } catch (exception) {
      if (mounted) {
        setState(() {
          isSaving = false;
          error = exception.toString().replaceFirst('Bad state: ', '');
        });
      }
      return;
    }
    if (mounted) {
      setState(() => isSaving = false);
      widget.onComplete();
    }
  }
}
