import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../child_soft_ui.dart';
import 'document_page.dart';

class TechSupportPage extends StatelessWidget {
  const TechSupportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
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
                  'Если есть вопросы по доступу, подписке или оплате, напишите нам на почту.',
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
                            Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                              child: FigmaGradientButton(
                                label: 'Закрыть',
                                gradient:
                                    FigmaGradientButton.mintGradientVertical,
                                height: kFigmaLandingCtaHeight,
                                labelStyle: kFigmaLandingCtaTextStyle,
                                boxShadow: kFigmaLandingCtaBoxShadows,
                                textHeightBehavior: const TextHeightBehavior(
                                  applyHeightToFirstAscent: false,
                                  applyHeightToLastDescent: false,
                                ),
                                onTap: () => Navigator.pop(ctx),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: kBrandSky,
                    foregroundColor: kChildInk,
                    textStyle:
                        kFigmaLandingCtaTextStyle.copyWith(color: kChildInk),
                  ),
                  child: const Text('Написать в поддержку'),
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
          minimumSize: const Size.fromHeight(kFigmaLandingCtaHeight),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kFigmaLandingCtaHeight / 2),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
