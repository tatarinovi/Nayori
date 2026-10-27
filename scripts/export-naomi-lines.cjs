// Пересобрать читаемый каталог: node scripts/export-naomi-lines.cjs
const fs = require('node:fs'), vm = require('node:vm'), path = require('node:path')
const root = path.resolve(__dirname, '..'), ctx = {}
vm.runInNewContext(fs.readFileSync(path.join(root, 'services/companion/NaomiLines.js'), 'utf8'), ctx)
const l = ctx.lines
let out = '# Все реплики Naomi\n\nИсточник: `services/companion/NaomiLines.js`. Каталог пересобирается командой `node scripts/export-naomi-lines.cjs`. Характер и правила появления — в [NAOMI_CHARACTER.md](NAOMI_CHARACTER.md).\n\n'
let count = 0
function section(title, values) {
    out += `## ${title}\n\n`
    for (const text of values) { out += `- ${text}\n`; count++ }
    out += '\n'
}
const parts = {morning:'Утро',day:'День',evening:'Вечер',night:'Ночь',any:'Неизвестное время'}
for (const [k, label] of Object.entries(parts)) section(`Приветствия — ${label}`, l.greeting[k])
section('Случайные реплики', l.idle)
for (const [k,label] of Object.entries({petStart:'Первое поглаживание',petAgain:'Повторное поглаживание',petLong:'Длительное поглаживание',petEnd:'Завершение поглаживания'})) section(label,l[k])
const events = {cpu:'Нагрузка CPU',idle:'Нет ввода 10 минут',terminal:'Открытие терминала',game:'Запуск игры',battery:'Низкий заряд',windows:'Больше пяти окон',night:'Позднее время',update:'Начало обновления',offline:'Потеря интернета',return:'Возвращение ввода',musicStart:'Яндекс Музыка — начало воспроизведения',musicStop:'Яндекс Музыка — пауза или остановка',hoverStill:'Курсор неподвижен на Naomi больше 5 секунд'}
for (const [k,base] of Object.entries(l.system)) section(`События — ${events[k] || k}`, [base,...(l.systemVariants[k] || [])])
for (const [k,label] of Object.entries({water:'Вода',eyes:'Глаза',move:'Разминка'}))
    for (const [stage,values] of Object.entries(l.remind[k])) section(`Напоминания — ${label}: ${{prompt:'предложение',ack:'подтверждение',count:'отсчёт',done:'завершение'}[stage]}`,values)
out += `Всего реплик: **${count}**.\n\n## Подстановка времени\n\n`
l.nightTimes.forEach((text,h) => { out += `- ${h}: ${text}\n` })
fs.writeFileSync(path.join(root, 'docs/naomi-lines.md'), out)
console.log(`Naomi: ${count} lines exported`)
