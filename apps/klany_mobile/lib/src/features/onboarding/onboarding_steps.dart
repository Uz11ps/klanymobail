import 'onboarding_tour_dialog.dart';

const parentTourTitle = 'Мини-тур для родителя';
const childTourTitle = 'Мини-тур для ребёнка';

const parentTourSteps = <TourStepData>[
  TourStepData(
    title: 'Главная',
    description: 'Сводка по семье, балансу детей и быстрые действия.',
  ),
  TourStepData(
    title: 'Квесты',
    description:
        'Создавайте задания, настраивайте автоапрув и проверяйте статус.',
  ),
  TourStepData(
    title: 'Магазин',
    description: 'Управляйте товарами и подтверждайте заявки на покупки.',
  ),
  TourStepData(
    title: 'Кошелек',
    description: 'Следите за балансами детей и начислениями.',
  ),
  TourStepData(
    title: 'Заявки',
    description: 'Подтверждайте вход ребёнка на новом устройстве.',
  ),
  TourStepData(
    title: 'Штаб',
    description: 'Раздел управления семьёй и дополнительными настройками.',
  ),
];

const childTourSteps = <TourStepData>[
  TourStepData(
    title: 'Главная',
    description: 'Здесь видно баланс и количество активных заданий.',
  ),
  TourStepData(
    title: 'Квесты',
    description: 'Открывайте задания, берите в работу и отмечайте выполнение.',
  ),
  TourStepData(
    title: 'Кошелёк',
    description: 'Проверяйте, сколько монет уже начислено.',
  ),
  TourStepData(
    title: 'Магазин',
    description: 'Тут можно тратить монеты на выбранные награды.',
  ),
  TourStepData(
    title: 'Настройки',
    description: 'Установите PIN-код для быстрого и безопасного входа.',
  ),
];
