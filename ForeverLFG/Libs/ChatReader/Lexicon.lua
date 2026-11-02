local _,Root=...
local NS=Root.ChatReader or Root
-- Literal dictionaries: no downloaded code, no model calls, no item-name guessing.
local L={rules={},professions={},channels={},roles={}};NS.Lexicon=L
local function words(s) local out={} for w in s:gmatch("[^|]+") do out[#out+1]=w end return out end
local function rules(locale,defs)
    for action,s in pairs(defs) do
        for _,term in ipairs(words(s)) do
            L.rules[#L.rules+1]={id=locale.."."..action.."."..(#L.rules+1),locale=locale,action=action,term=term,substring=locale:match("^zh")~=nil or locale=="koKR"}
        end
    end
end
rules("und",{buy="wtb",sell="wts",offer="lfw|lf work",request="lf",group_seek="lfg",group_offer="lfm"})
rules("enUS",{
 buy="buying|want to buy",sell="selling|want to sell",request="looking for|need|can anyone|can someone|who can|anyone can",
 offer="can craft|crafting services|offering|looking for work|for tips|tips welcome|your mats",craft="craft|crafting|crafter|make|enchant",
 cancel="no longer need|no longer looking|not looking for|sold out|never mind|nevermind|found someone|found one|nvm",
 group_seek="looking for group|need help",group_offer="looking for more|need tank|need healer",
 guild="guild recruiting|guild recruitment|recruiting guild",negate="not selling|not buying|do not sell|can't craft|cannot craft|not offering",
 mats_self="my mats|have mats|mats ready|own mats",mats_other="your mats|bring mats",mats_missing="no mats|without mats|need mats",
 negotiable="negotiable|obo",tip="tips|tip",per_item="each|per item",per_stack="per stack",per_craft="per craft",service="portal|portals|summon|summons|lockpicking|lockpick"})
rules("ruRU",{
 buy="куплю|покупаю|скупаю",sell="продам|продаю",request="ищу|нужен|нужна|нужно|нужны|кто может|кто сделает|кто умеет",
 offer="сделаю|крафчу|изготовлю|предлагаю|зачарую|наложу|ваши реги|ваши материалы",craft="крафт*|скрафт*|изготов*|зачар*|чары",
 cancel="больше не нужно|больше не нужен|уже нашел|уже нашёл|всё продано|все продано|продано|отбой|не актуально|неактуально",
 group_seek="ищу группу|нужна помощь",group_offer="добор|собираю группу|ищем танка|ищем хила",guild="набор в гильдию|гильдия набирает",
 negate="не продаю|не покупаю|не умею|не делаю|не предлагаю",mats_self="мои реги|мои материалы|реги мои|реги есть|материалы есть",
 mats_other="ваши реги|ваши материалы|с вашими реагентами",mats_missing="без регов|регов нет|нет материалов",
 negotiable="торг|договоримся",tip="чаевые|за чай",per_item="за штуку|за шт|штука",per_stack="за стак|стак",per_craft="за крафт",service="портал*|суммон*|призыв|вскрытие замков|вскрою замок"})
rules("deDE",{
 buy="kaufe|suche zu kaufen",sell="verkaufe|verkauf",request="suche|brauche|wer kann|kann jemand",offer="stelle her|biete|eure mats|verzaubere",
 craft="herstellen|handwerker|anfertigen|verzauber*",cancel="nicht mehr benötigt|nicht mehr gesucht|schon gefunden|alles verkauft|erledigt",
 group_seek="suche gruppe",group_offer="suchen tank|suchen heiler|suchen mitspieler",guild="gilde sucht|gildenrekrutierung",
 negate="verkaufe nicht|kaufe nicht|kann nicht",mats_self="eigene mats|habe mats",mats_other="eure mats|deine mats",mats_missing="ohne mats|keine mats",
 negotiable="verhandelbar|vhb",tip="trinkgeld",per_item="pro stück",per_stack="pro stapel|pro stack",per_craft="pro herstellung",service="portal|portale|beschwörung|schlösser knacken"})
rules("frFR",{
 buy="achète|achete|achat",sell="vends|vend|vente",request="cherche|recherche|besoin|qui peut",offer="fabrique|propose|vos compos|enchante",
 craft="craft|fabriquer|artisan|enchant*",cancel="plus besoin|déjà trouvé|deja trouve|tout vendu|annulé|annule",
 group_seek="cherche groupe",group_offer="cherche tank|cherche heal|recherche tank",guild="guilde recrute",negate="ne vends pas|ne vend pas|ne peux pas",
 mats_self="mes compos|j ai les compos",mats_other="vos compos|tes compos",mats_missing="sans compos",negotiable="négociable|negociable",tip="pourboire",
 per_item="pièce|piece|unité|unite",per_stack="le stack|par pile",per_craft="par craft",service="portail*|invocation|crochetage"})
rules("esES",{
 buy="compro|comprando",sell="vendo|vendiendo",request="busco|necesito|alguien puede|quién puede|quien puede",offer="fabrico|ofrezco|encanto|tus materiales",
 craft="fabricar|artesano|crafte*|encant*",cancel="ya no necesito|ya encontré|ya encontre|todo vendido|cancelado",
 group_seek="busco grupo",group_offer="buscamos tanque|buscamos sanador|faltan jugadores",guild="hermandad recluta",negate="no vendo|no compro|no puedo",
 mats_self="mis materiales|tengo materiales",mats_other="tus materiales",mats_missing="sin materiales",negotiable="negociable",tip="propina*",
 per_item="por unidad|cada uno",per_stack="por lote|por stack",per_craft="por fabricación|por fabricacion",service="portal*|invocación|invocacion|abrir cerraduras"})
-- esMX shares the Spanish rules; candidates explicitly include both client locales.
rules("ptBR",{
 buy="compro|comprando",sell="vendo|vendendo",request="procuro|preciso|alguém pode|alguem pode|quem faz",offer="faço|faco|ofereço|ofereco|seus materiais",
 craft="fabricar|criar|artesão|artesao|encant*",cancel="não preciso mais|nao preciso mais|já achei|ja achei|tudo vendido|cancelado",
 group_seek="procuro grupo",group_offer="procuramos tanque|procuramos healer",guild="guilda recruta",negate="não vendo|nao vendo|não compro|nao compro|não posso",
 mats_self="meus materiais|tenho materiais",mats_other="seus materiais",mats_missing="sem materiais",negotiable="negociável|negociavel",tip="gorjeta*",
 per_item="cada|por unidade",per_stack="por stack|por pilha",per_craft="por fabricação|por fabricacao",service="portal|portais|evocação|evocacao|arrombamento"})
rules("itIT",{
 buy="compro|acquisto",sell="vendo|vendita",request="cerco|mi serve|qualcuno può|qualcuno puo",offer="creo|offro|vostri materiali",
 craft="creare|fabbricare|artigiano|incant*",cancel="non serve più|non serve piu|già trovato|gia trovato|tutto venduto|annullato",
 group_seek="cerco gruppo",group_offer="cerchiamo tank|cerchiamo curatore",guild="gilda recluta",negate="non vendo|non compro|non posso",
 mats_self="miei materiali|ho i materiali",mats_other="vostri materiali",mats_missing="senza materiali",negotiable="trattabile",tip="mancia",
 per_item="ciascuno|al pezzo",per_stack="per pila|per stack",per_craft="per creazione",service="portale|portali|evocazione|scassinare"})
rules("koKR",{
 buy="삽니다|구매합니다|구입",sell="팝니다|판매합니다|판매",request="구합니다|찾습니다|부탁",offer="제작합니다|제작해|해드립니다|마부해",
 craft="제작|만들|마부",cancel="구했습니다|판매완료|거래완료|취소",group_seek="파티 구함|파티구함",group_offer="탱 구함|힐 구함|파티 모집",
 guild="길드 모집",negate="안 팔|안팝|제작 불가",mats_self="재료 있음|제 재료",mats_other="재료 지참",mats_missing="재료 없음",negotiable="흥정",tip="팁",
 per_item="개당",per_stack="묶음당",per_craft="제작당",service="포탈|소환|자물쇠"})
rules("zhCN",{
 buy="收购|求购|收材料",sell="出售|卖|出手",request="求|找|谁会|需要",offer="代工|可做|可以做|来料加工",
 craft="制作|打造|加工|附魔",cancel="已售|卖完|已找到|取消|不需要了",group_seek="求组|找队伍",group_offer="来T|来奶|招募队友",guild="公会招人",
 negate="不卖|不收|不会做",mats_self="自备材料|材料我出",mats_other="来料|自带材料",mats_missing="没材料|无材料",negotiable="可议价|可议",tip="小费",
 per_item="每个|单个",per_stack="每组|一组",per_craft="每次",service="传送门|传送|拉人|开锁"})
rules("zhTW",{
 buy="收購|求購|收材料",sell="出售|賣|出手",request="求|找|誰會|需要",offer="代工|可做|可以做|來料加工",
 craft="製作|打造|加工|附魔",cancel="已售|賣完|已找到|取消|不需要了",group_seek="求組|找隊伍",group_offer="來坦|來補|招募隊友",guild="公會招人",
 negate="不賣|不收|不會做",mats_self="自備材料|材料我出",mats_other="來料|自帶材料",mats_missing="沒材料|無材料",negotiable="可議價|可議",tip="小費",
 per_item="每個|單個",per_stack="每組|一組",per_craft="每次",service="傳送門|傳送|拉人|開鎖"})
-- Participation phrases require a genuine quest link in the recognizer.
rules("enUS",{group_invite="anyone for|anyone up for|anyone want to do|join me|join us"})
rules("ruRU",{group_invite="кто со мной|кто пойдет|кто пойдёт|кто на|вместе сделаем"})
rules("deDE",{group_invite="wer kommt mit|wer macht mit"})
rules("frFR",{group_invite="qui pour|qui vient|qui veut faire"})
rules("esES",{group_invite="alguien para|quién se apunta|quien se apunta"})
rules("ptBR",{group_invite="alguém para|alguem para|quem vem"})
rules("itIT",{group_invite="qualcuno per|chi viene"})
rules("koKR",{group_invite="같이 하실분|같이하실분|같이 하실 분|같이하실 분|하실분|하실 분|같이 가실분|같이가실분|가실분|가실 분"})
rules("zhCN",{group_invite="有人一起|一起做|一起打|一起去"})
rules("zhTW",{group_invite="有人一起|一起做|一起打|一起去|一起解"})
rules("enUS",{negate="don't join|do not join|not doing|not going"})
rules("ruRU",{negate="не пойду|не собираю|не ищу группу"})
rules("koKR",{negate="안 합니다|안 갑니다|모집 안|안 하실"})
local function roles(locale,tank,healer,damage)
    for i,s in ipairs({tank,healer,damage}) do for _,term in ipairs(words(s)) do
        L.roles[#L.roles+1]={role=({"tank","healer","damage"})[i],locale=locale,term=term,substring=locale:match("^zh")~=nil}
    end end
end
roles("enUS","tank|tanks","healer|healers|heal","dps|damage")
roles("ruRU","танк|танка","хил|хила|хилер|хилера|лекарь","дд|дамагер")
roles("deDE","tank","heiler","dd|dps")
roles("frFR","tank","soigneur|heal","dps")
roles("esES","tanque","sanador|healer","dps")
roles("ptBR","tanque","curador|healer","dps")
roles("itIT","tank","curatore|healer","dps")
roles("koKR","탱|탱커","힐|힐러","딜|딜러")
roles("zhCN","坦克|坦|来t","治疗|奶","输出")
roles("zhTW","坦克|坦|來t","治療|補","輸出")
-- Sort for deterministic evidence and exports (pairs iteration is unspecified in Lua 5.1).
table.sort(L.rules,function(a,b) return a.locale..":"..a.action..":"..a.term < b.locale..":"..b.action..":"..b.term end)
for i,r in ipairs(L.rules) do r.id=r.locale.."."..r.action.."."..i end
local keys={"blacksmithing","leatherworking","enchanting","alchemy","tailoring","engineering","cooking","first_aid","mining","herbalism","skinning","fishing"}
local function profs(locale,rows)
    for i,row in ipairs(rows) do for _,term in ipairs(words(row)) do
        L.professions[#L.professions+1]={key=keys[i],term=term,locale=locale,substring=locale:match("^zh")~=nil or locale=="koKR"}
    end end
end
profs("enUS",{"blacksmith*|blacksmithing|bs","leatherwork*|lw","enchanter*|enchanting|ench","alchem*|alch","tailor*","engineer*|engi","cook*","first aid","mining|miner","herbalism|herbalist","skinning|skinner","fishing|fisher"})
profs("ruRU",{"кузнец*|кузнеч*","кожев*","наложение чар|зачаровател*|энчант*|энчантер*","алхим*","портня*|портной|портного","инженер*","кулинар*|повар*","первая помощь|первой помощи","горное дело|горняк*","травнич*|травник*","снятие шкур|скорняк*","рыбная ловля|рыбак*"})
profs("deDE",{"schmied*|schmiedekunst","lederverarbeit*","verzauber*","alchemi*","schneider*","ingenieur*","koch*","erste hilfe","bergbau","kräuterkunde|krauterkunde","kürschnerei|kurschnerei","angeln"})
profs("frFR",{"forgeron|forge","travail du cuir|travailleur du cuir","enchanteur|enchantement","alchim*","couture|couturier","ingénierie|ingenierie|ingénieur|ingenieur","cuisine|cuisinier","secourisme","minage|mineur","herborist*","dépeçage|depecage","pêche|peche"})
profs("esES",{"herrer*","peleter*","encantador|encantamiento","alquimi*","sastr*","ingenier*","cocina|cocinero","primeros auxilios","minería|mineria","herborist*","desuello","pesca"})
profs("ptBR",{"ferreiro|ferraria","couraria|coureiro","encantador|encantamento","alquimi*","alfaiat*","engenh*","culinária|culinaria|cozinheiro","primeiros socorros","mineração|mineracao","herborismo","esfolamento","pesca"})
profs("itIT",{"fabbro|forgiatura","conciatura|conciatore","incantatore|incantamento","alchimi*","sartoria|sarto","ingegner*","cucina|cuoco","primo soccorso","estrazione","erboristeria","scuoiatura","pesca"})
profs("koKR",{"대장","가죽세공","마법부여|마부","연금","재봉","기계공학","요리","응급치료","채광","약초채집","무두질","낚시"})
profs("zhCN",{"锻造","制皮","附魔","炼金","裁缝","工程","烹饪","急救","采矿","草药|采药","剥皮","钓鱼"})
profs("zhTW",{"鍛造","製皮","附魔","鍊金|煉金","裁縫","工程","烹飪","急救","採礦","草藥|採藥","剝皮","釣魚"})
local channelNames={
 trade={"trade","tradelocal","local trade","trade (local)","торговля","торговлялокальный","handel","commerce","comercio","comércio","commercio","거래","交易"},
 trade_services={"services","trade (services)","trade services","торговля (услуги)","торговля: услуги","handel (dienstleistungen)","commerce (services)","comercio (servicios)","comércio (serviços)","commercio (servizi)","거래 (서비스)","交易 (服务)","交易 (服務)"},
 general={"general","общий","allgemein","général","general","geral","generale","공개","综合","綜合"},
 lfg={"lookingforgroup","looking for group","поиск спутников","поиск группы","suche nach gruppe","recherchedegroupe","recherche de groupe","buscargrupo","buscar grupo","procurandogrupo","cerca gruppo","파티찾기","寻求组队","尋求組隊"}}
for key,names in pairs(channelNames) do for _,name in ipairs(names) do L.channels[NS.Text.Normalize(name)]=key end end
