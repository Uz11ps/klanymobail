import 'onboarding_tour_dialog.dart';

const parentTourTitle = 'Мини-тур для родителя';
const childTourTitle = 'Мини-тур для ребёнка';

/// Только действия главы клана. Разделы «как у ребёнка» — в [childTourSteps].
const parentTourSteps = <TourStepData>[
  TourStepData(
    title: 'Главная',
    description:
        'Сводка по семье, балансу детей и быстрые действия.',
  ),
  TourStepData(
    title: 'Заявки',
    description:
        'Подтверждайте вход ребёнка с нового устройства и управляйте доступом.',
  ),
  TourStepData(
    title: 'Штаб',
    description:
        'Настройки семьи: цели, участники, коды входа, подписка и налог.',
  ),
];

/// В том числе разделы, которые ребёнок использует сам (перенесены из тура родителя).
const childTourSteps = <TourStepData>[
  TourStepData(
    title: 'Главная',
    description: 'Здесь видно баланс и количество активных заданий.',
  ),
  TourStepData(
    title: 'Квесты',
    description:
        'Открывайте задания, берите в работу и отмечайте выполнение.',
  ),
  TourStepData(
    title: 'Кошелёк',
    description: 'Проверяйте, сколько монет уже начислено.',
  ),
  TourStepData(
    title: 'Магазин',
    description: 'Тратьте монеты на награды, которые настроил родитель.',
  ),
  TourStepData(
    title: 'Настройки',
    description: 'PIN-код и повторный показ этого тура.',
  ),
];
