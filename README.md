# Internationalization - Docker mod for all containers to add fonts and non en_US language support

This mod adds fonts and locales to an image, to be installed/updated during container start.

In your container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:internationalization`

For this language you will need to set the following environment variables as well:

`LC_ALL=en_US`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Word of warning

This mod on some base images is massive, (hundreds of megs compressed gigs uncompressed). It does not filter down to specific languages needed and is meant as a catch all for non english users. Depending on the speed/quality of your connection this means first init for installation can take some time, locales generation as well. Expect anywhere from 5-15 minutes. Once finished and on subsequent restarts it will not be re-ran as the logic checks for the presence of itself on the filesystem, but on upgrades or full container recreation this will run again.

# 国际化 - Docker mod 为所有容器添加字体和非 en_US 语言支持

此 mod 将字体和语言环境添加到图像中，以便在容器启动期间安装/更新。

在容器的 docker 参数中，设置环境变量 `DOCKER_MODS=linuxserver/mods:internationalization`

对于这种语言，您还需要设置以下环境变量：

`LC_ALL=zh_CN`

如果添加多个mod，将它们输入到一个数组中，以`|`分隔，例如`DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## 警告词

一些基础图像上的这个 mod 是巨大的，（数百 megs 压缩演出未压缩）。 它不会过滤到所需的特定语言，而是为非英语用户准备的。 根据您的连接速度/质量，这意味着首次安装初始化可能需要一些时间，区域设置生成也是如此。 预计 5-15 分钟。 一旦完成并在随后的重新启动时，它将不会重新运行，因为逻辑会检查其自身是否存在于文件系统上，但在升级或完整的容器重建时，它将再次运行。

# 国際化 - フォントと非 en_US 言語サポートを追加するためのすべてのコンテナーの Docker mod

この mod は、イメージにフォントとロケールを追加し、コンテナーの起動時にインストール/更新します。

コンテナーの docker 引数で、環境変数 `DOCKER_MODS=linuxserver/mods:internationalization` を設定します。

この言語では、次の環境変数も設定する必要があります:

`LC_ALL=ja_JP`

複数の mod を追加する場合は、「DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2」のように「|」で区切られた配列に入力します

## 注意事項

一部の基本イメージのこの mod は大規模です (数百メガバイトの圧縮ギグが非圧縮)。 必要な特定の言語に絞り込むことはなく、英語以外のユーザー向けのキャッチ オールとして意図されています。 接続の速度/品質によっては、インストールの最初の初期化に時間がかかることを意味し、ロケールの生成も同様です。 5 ～ 15 分の範囲で期待してください。 ロジックがファイルシステム上にそれ自体が存在するかどうかをチェックするため、完了して以降の再起動時に再実行されることはありませんが、アップグレードまたは完全なコンテナの再作成時に再実行されます。

# التدويل - تعديل Docker لجميع الحاويات لإضافة خطوط ودعم لغة غير en_US 

يضيف هذا الوضع الخطوط واللغات إلى صورة ، ليتم تثبيتها / تحديثها أثناء بدء الحاوية. 

في وسيطات عامل إرساء الحاوية الخاصة بك ، قم بتعيين متغير بيئة `DOCKER_MODS = linuxserver / mods: internationalization` 

بالنسبة لهذه اللغة ، ستحتاج إلى تعيين متغيرات البيئة التالية أيضًا: 

`LC_ALL=ar_AE`

في حالة إضافة تعديلات متعددة ، أدخلها في مصفوفة مفصولة بـ `|` ، مثل `DOCKER_MODS = linuxserver / mods: internationalization | linuxserver / mods: mod2` 

## كلمة تحذير 

هذا التعديل في بعض الصور الأساسية ضخم ، (مئات الميغا من العربات المضغوطة غير مضغوطة). لا يتم التصفية حسب اللغات المحددة المطلوبة ويقصد به أن يكون بمثابة صيد لجميع المستخدمين غير الإنجليز. اعتمادًا على سرعة / جودة اتصالك ، يعني هذا أن أول بدء للتثبيت قد يستغرق بعض الوقت ، وكذلك إنشاء اللغات. توقع في أي مكان من 5-15 دقيقة. بمجرد الانتهاء وإعادة التشغيل اللاحقة ، لن تتم إعادة تشغيله حيث يتحقق المنطق من وجود نفسه على نظام الملفات ، ولكن عند الترقيات أو إعادة إنشاء الحاوية الكاملة ، سيعمل هذا مرة أخرى. 

# Интернационализация — мод Docker для всех контейнеров для добавления шрифтов и поддержки языков, отличных от en_US

Этот мод добавляет в изображение шрифты и локали, которые будут установлены/обновлены при запуске контейнера.

В аргументах docker вашего контейнера установите переменную среды `DOCKER_MODS=linuxserver/mods:internationalization`

Для этого языка вам также потребуется установить следующие переменные среды:

`LC_ALL=ru_RU`

При добавлении нескольких модов введите их в массив, разделенный символом `|`, например, `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Слово предупреждения

Этот мод на некоторых базовых образах является массивным (сотни мегабайт сжатых гигов без сжатия). Он не фильтрует нужные языки и предназначен для всех пользователей, не владеющих английским языком. В зависимости от скорости/качества вашего соединения это означает, что первая инициализация для установки может занять некоторое время, а также создание локалей. Ожидайте от 5 до 15 минут. После завершения и при последующих перезапусках он не будет запускаться повторно, так как логика проверяет свое присутствие в файловой системе, но при обновлении или полном воссоздании контейнера он будет запускаться снова.

# Internacionalización: mod de Docker para que todos los contenedores agreguen fuentes y compatibilidad con idiomas que no sean en_US

Este mod agrega fuentes y configuraciones regionales a una imagen, para que se instalen o actualicen durante el inicio del contenedor.

En los argumentos de la ventana acoplable de su contenedor, establezca una variable de entorno `DOCKER_MODS=linuxserver/mods:internationalization`

Para este idioma, también deberá configurar las siguientes variables de entorno:

`LC_ALL=es_MX`

Si agrega varias modificaciones, introdúzcalas en una matriz separada por `|`, como `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Palabra de advertencia

Este mod en algunas imágenes base es masivo (cientos de megas de conciertos comprimidos sin comprimir). No se filtra a los idiomas específicos que se necesitan y está pensado como una solución para todos los usuarios que no hablan inglés. Dependiendo de la velocidad/calidad de su conexión, esto significa que la primera inicialización para la instalación puede llevar algo de tiempo, así como la generación de locales. Espere entre 5 y 15 minutos. Una vez finalizado y en los reinicios posteriores, no se volverá a ejecutar, ya que la lógica comprueba su presencia en el sistema de archivos, pero en las actualizaciones o en la recreación completa del contenedor, se ejecutará de nuevo.

# Internationalisierung - Docker-Mod für alle Container zum Hinzufügen von Schriftarten und Unterstützung von nicht en_US-Sprachen

Dieser Mod fügt Schriftarten und Gebietsschemata zu einem Image hinzu, die während des Containerstarts installiert/aktualisiert werden.

Setzen Sie in den Docker-Argumenten Ihres Containers eine Umgebungsvariable `DOCKER_MODS=linuxserver/mods:internationalization`

Für diese Sprache müssen Sie auch die folgenden Umgebungsvariablen setzen:

`LC_ALL=de_DE`

Wenn Sie mehrere Mods hinzufügen, geben Sie sie in einem durch `|` getrennten Array ein, wie z. B. `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Warnung

Dieser Mod auf einigen Basis-Images ist massiv (Hunderte von MB komprimierte Gigs unkomprimiert). Es filtert nicht nach bestimmten Sprachen, die benötigt werden, und ist als Sammelpunkt für nicht englische Benutzer gedacht. Abhängig von der Geschwindigkeit/Qualität Ihrer Verbindung bedeutet dies, dass die erste Initialisierung für die Installation einige Zeit in Anspruch nehmen kann, ebenso wie die Generierung der Gebietsschemas. Rechnen Sie mit 5-15 Minuten. Nach Abschluss und bei nachfolgenden Neustarts wird es nicht erneut ausgeführt, da die Logik prüft, ob es sich selbst im Dateisystem befindet, aber bei Upgrades oder der vollständigen Wiederherstellung des Containers wird es erneut ausgeführt.

# Internationalisation - Mod Docker pour tous les conteneurs pour ajouter des polices et un support de langue non en_US

Ce mod ajoute des polices et des paramètres régionaux à une image, à installer/mettre à jour lors du démarrage du conteneur.

Dans les arguments docker de votre conteneur, définissez une variable d'environnement `DOCKER_MODS=linuxserver/mods:internationalization`

Pour cette langue, vous devrez également définir les variables d'environnement suivantes :

`LC_ALL=fr_FR`

Si vous ajoutez plusieurs mods, entrez-les dans un tableau séparé par `|`, comme `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Mot d'avertissement

Ce mod sur certaines images de base est massif (des centaines de mégas de concerts compressés non compressés). Il ne filtre pas les langues spécifiques nécessaires et est conçu comme un fourre-tout pour les utilisateurs non anglophones. En fonction de la vitesse/qualité de votre connexion, cela signifie que la première initialisation de l'installation peut prendre un certain temps, ainsi que la génération des paramètres régionaux. Attendez-vous entre 5 et 15 minutes. Une fois terminé et lors des redémarrages suivants, il ne sera pas réexécuté car la logique vérifie sa présence sur le système de fichiers, mais lors des mises à niveau ou de la recréation complète du conteneur, cela s'exécutera à nouveau.

# Internationalisering - Docker-mod voor alle containers om lettertypen en niet-en_US-taalondersteuning toe te voegen

Deze mod voegt lettertypen en landinstellingen toe aan een afbeelding, die moeten worden geïnstalleerd/geüpdatet tijdens het starten van de container.

Stel in de docker-argumenten van uw container een omgevingsvariabele in `DOCKER_MODS=linuxserver/mods:internationalization`

Voor deze taal moet u ook de volgende omgevingsvariabelen instellen:

`LC_ALL=nl_NL`

Als u meerdere mods toevoegt, voert u deze in een array in gescheiden door `|`, zoals `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Waarschuwing

Deze mod op sommige basisafbeeldingen is enorm (honderden megs gecomprimeerde optredens ongecomprimeerd). Het filtert niet naar specifieke talen die nodig zijn en is bedoeld als verzamelpunt voor niet-Engelse gebruikers. Afhankelijk van de snelheid/kwaliteit van uw verbinding betekent dit dat de eerste init voor installatie enige tijd kan duren, evenals het genereren van locales. Verwacht ergens tussen de 5 en 15 minuten. Eenmaal voltooid en bij daaropvolgende herstarts zal het niet opnieuw worden uitgevoerd omdat de logica controleert op de aanwezigheid van zichzelf op het bestandssysteem, maar bij upgrades of volledige containerrecreatie zal dit opnieuw worden uitgevoerd.

# Internazionalizzazione: mod Docker per tutti i contenitori per aggiungere caratteri e supporto per lingue non en_US

Questa mod aggiunge caratteri e locali a un'immagine, da installare/aggiornare durante l'avvio del contenitore.

Negli argomenti docker del tuo contenitore, imposta una variabile di ambiente `DOCKER_MODS=linuxserver/mods:internationalization`

Per questa lingua dovrai impostare anche le seguenti variabili d'ambiente:

`LC_ALL=it_IT`

Se aggiungi più mod, inseriscile in un array separato da `|`, ad esempio `DOCKER_MODS=linuxserver/mods:internationalization|linuxserver/mods:mod2`

## Parola di avvertimento

Questa mod su alcune immagini di base è enorme (centinaia di mega giga compressi non compressi). Non filtra le lingue specifiche necessarie ed è inteso come una cattura per tutti gli utenti non inglesi. A seconda della velocità/qualità della tua connessione, ciò significa che il primo init per l'installazione può richiedere del tempo, anche la generazione dei locali. Aspettati ovunque da 5-15 minuti. Una volta terminato e ai successivi riavvii, non verrà eseguito nuovamente poiché la logica verifica la presenza di se stesso sul filesystem, ma durante gli aggiornamenti o la ricreazione del contenitore completo verrà eseguito di nuovo.



# Other languages

The following language locales are also supported: 

```
aa_DJ
aa_ER
aa_ET
af_ZA
am_ET
an_ES
ar_AE
ar_BH
ar_DZ
ar_EG
ar_IN
ar_IQ
ar_JO
ar_KW
ar_LB
ar_LY
ar_MA
ar_OM
ar_QA
ar_SA
ar_SD
ar_SY
ar_TN
ar_YE
as_IN
ast_ES
ayc_PE
az_AZ
be_BY
bem_ZM
ber_DZ
ber_MA
bg_BG
bho_IN
bn_BD
bn_IN
bo_CN
bo_IN
br_FR
brx_IN
bs_BA
byn_ER
ca_AD
ca_ES
ca_FR
ca_IT
crh_UA
csb_PL
cs_CZ
cv_RU
cy_GB
da_DK
de_AT
de_BE
de_CH
de_DE
de_LU
doi_IN
dv_MV
dz_BT
el_CY
el_GR
en_AG
en_AU
en_BW
en_CA
en_DK
en_GB
en_HK
en_IE
en_IN
en_NG
en_NZ
en_PH
en_SG
en_US
en_ZA
en_ZM
en_ZW
es_AR
es_BO
es_CL
es_CO
es_CR
es_CU
es_DO
es_EC
es_ES
es_GT
es_HN
es_MX
es_NI
es_PA
es_PE
es_PR
es_PY
es_SV
es_US
es_UY
es_VE
et_EE
eu_ES
fa_IR
ff_SN
fi_FI
fil_PH
fo_FO
fr_BE
fr_CA
fr_CH
fr_FR
fr_LU
fur_IT
fy_DE
fy_NL
ga_IE
gd_GB
gez_ER
gez_ET
gl_ES
gu_IN
gv_GB
ha_NG
he_IL
hi_IN
hne_IN
hr_HR
hsb_DE
ht_HT
hu_HU
hy_AM
ia_FR
id_ID
ig_NG
ik_CA
is_IS
it_CH
it_IT
iu_CA
ja_JP
ka_GE
kk_KZ
kl_GL
km_KH
kn_IN
kok_IN
ko_KR
ks_IN
ku_TR
kw_GB
ky_KG
lb_LU
lg_UG
li_BE
lij_IT
li_NL
lo_LA
lt_LT
lv_LV
mag_IN
mai_IN
mg_MG
mhr_RU
mi_NZ
mk_MK
ml_IN
mni_IN
mn_MN
mr_IN
ms_MY
mt_MT
my_MM
nb_NO
nds_DE
nds_NL
ne_NP
nhn_MX
niu_NU
niu_NZ
nl_AW
nl_BE
nl_NL
nn_NO
nr_ZA
nso_ZA
oc_FR
om_ET
om_KE
or_IN
os_RU
pa_IN
pa_PK
pl_PL
ps_AF
pt_BR
pt_PT
ro_RO
ru_RU
ru_UA
rw_RW
sa_IN
sat_IN
sc_IT
sd_IN
se_NO
shs_CA
sid_ET
si_LK
sk_SK
sl_SI
so_DJ
so_ET
so_KE
so_SO
sq_AL
sq_MK
sr_ME
sr_RS
ss_ZA
st_ZA
sv_FI
sv_SE
sw_KE
sw_TZ
szl_PL
ta_IN
ta_LK
te_IN
tg_TJ
th_TH
ti_ER
ti_ET
tig_ER
tk_TM
tl_PH
tn_ZA
tr_CY
tr_TR
ts_ZA
tt_RU
ug_CN
uk_UA
unm_US
ur_IN
ur_PK
uz_UZ
ve_ZA
vi_VN
wa_BE
wae_CH
wal_ET
wo_SN
xh_ZA
yi_US
yo_NG
yue_HK
zh_CN
zh_HK
zh_SG
zh_TW
zu_ZA
```
