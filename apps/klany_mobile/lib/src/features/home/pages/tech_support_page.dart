import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../child_soft_ui.dart';
import 'document_page.dart';

class TechSupportPage extends StatelessWidget {
  const TechSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kChildInk),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        centerTitle: true,
        title: const Text(
          'Техподдержка',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: kChildInk,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ── Связаться с поддержкой ─────────────────────────
          ChildSoftCard(
            color: kChildSurfaceWhite,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Связаться с поддержкой',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Если есть вопросы по доступу, подписке, оплате или публикации приложения, напишите нам на почту.',
                  style: TextStyle(
                    fontSize: 14,
                    color: kChildInk,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'support@clancapital.ru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: kChildInk,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Обычно отвечаем в течении 3 рабочих дней.',
                  style: TextStyle(fontSize: 13, color: kChildInkMuted),
                ),
                const SizedBox(height: 14),
                const Divider(height: 1, color: kChildOutline),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: () async {
                    const url = 'mailto:support@clancapital.ru';
                    final ok = await canLaunchUrlString(url);
                    if (ok) {
                      await launchUrlString(url);
                    } else if (context.mounted) {
                      await showDialog<void>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Почта поддержки'),
                          content: const SelectableText(
                            'support@clancapital.ru\n\nНа этом устройстве нет почтового клиента. Скопируйте адрес и отправьте письмо удобным способом.',
                            style: TextStyle(fontSize: 14),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Закрыть'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandSky,
                    foregroundColor: kChildInk,
                    elevation: 4,
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Написать в поддержку',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Юридические документы ─────────────────────────
          ChildSoftCard(
            color: kChildSurfaceWhite,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _SupportSectionTitle('Юридические документы'),
                _SupportSkyButton(
                  label: 'Пользовательское\nсоглашение',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DocumentPage(
                        title: 'Соглашение',
                        body: userAgreementBody,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SupportSkyButton(
                  label: 'Политика\nконфиденциальности',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DocumentPage(
                        title: 'Политика',
                        body: privacyPolicyBody,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _SupportSkyButton(
                  label: 'Оферта о подписке\n(Premium)',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DocumentPage(
                        title: 'Оферта',
                        body: premiumOfferBody,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const _SupportSectionTitle('Управление данными'),
                _SupportSkyButton(
                  label: 'Согласие на обработку\nПД',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DocumentPage(
                        title: 'Согласие на ПД',
                        body: dataConsentBody,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ── Для публикации в RuStore ──────────────────────
          ChildSoftCard(
            color: kChildSurfaceWhite,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: const [
                Text(
                  'Для публикации в RuStore',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: kChildInk,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'В приложении уже доступны политика, согласия и контакты поддержки. Для карточки стора дополнительно понадобятся иконка, скриншоты и публичная ссылка на политику.',
                  style: TextStyle(
                    fontSize: 14,
                    color: kChildInk,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Публичную web-ссылку на политику конфиденциальности нужно разместить на сайте проекта или сервере, который доступен модерации RuStore.',
                  style: TextStyle(
                    fontSize: 14,
                    color: kChildInk,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSectionTitle extends StatelessWidget {
  const _SupportSectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: kChildInk,
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1, color: kChildOutline),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _SupportSkyButton extends StatelessWidget {
  const _SupportSkyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: kBrandSky,
          foregroundColor: kChildInk,
          elevation: 4,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
      ),
    );
  }
}
