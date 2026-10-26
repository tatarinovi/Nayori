const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const path = require('node:path');
const logic = {};
vm.createContext(logic);
vm.runInContext(fs.readFileSync(path.join(__dirname, '../surfaces/clipboard/ClipboardLogic.js'), 'utf8'), logic);
const records = [{id:'a',kind:'image',title:'Обои',text:'',pinned:true},
    {id:'b',kind:'text',title:'Текст',text:'Лаванда\nРоза',pinned:false}];
assert.equal(logic.filtered(records, 'ЛАВАНДА', 'all')[0].id, 'b');
assert.equal(logic.filtered(records, '', 'image').length, 1);
assert.equal(logic.filtered(records, '', 'pinned')[0].id, 'a');
assert.equal(logic.filtered(records, 'Обои', 'text').length, 0);
for (const [x, width, available] of [[10,580,1920],[1900,580,1920],[5,296,320],[319,296,320]]) {
    const placed = logic.placement(x,width,available,12,12);
    assert(placed >= 12);
    assert(placed + width <= available - 12);
}
assert.equal(logic.placement(100,580,1920,12,12), 112);
assert.equal(logic.placement(1900,580,1920,12,12), 1308);
assert.equal(logic.relativeTime(0, 120000), '2 мин');
assert.equal(logic.sizeLabel(1024), '1 КБ');
assert.equal(logic.metadata({kind:'image',format:'PNG',bytes:2048,width:1920,height:1080}), 'PNG · 2 КБ · 1920 × 1080');
assert.equal(logic.filtered([{kind:'video',title:'Video',text:''}], '', 'media').length, 1);
console.log('CLIPBOARD_LOGIC_TESTS_PASS');
