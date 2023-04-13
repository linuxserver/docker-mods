# Internationalization - Docker mod for all containers to add fonts and non en_US language support

This mod adds fonts and locales to an image, to be installed/updated during container start.

In your container's docker arguments, set an environment variable `DOCKER_MODS=linuxserver/mods:universal-internationalization`

For this language you will need to set the following environment variables as well:

`LC_ALL=en_US.UTF-8`

If adding multiple mods, enter them in an array separated by `|`, such as `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Word of warning

This mod on some base images is massive, (hundreds of megs compressed gigs uncompressed). It does not filter down to specific languages needed and is meant as a catch all for non english users. Depending on the speed/quality of your connection this means first init for installation can take some time, locales generation as well. Expect anywhere from 5-15 minutes. Once finished and on subsequent restarts it will not be re-ran as the logic checks for the presence of itself on the filesystem, but on upgrades or full container recreation this will run again.

# 国际化 - Docker mod 为所有容器添加字体和非 en_US 语言支持

此 mod 将字体和语言环境添加到图像中，以便在容器启动期间安装/更新。

在容器的 docker 参数中，设置环境变量 `DOCKER_MODS=linuxserver/mods:universal-internationalization`

对于这种语言，您还需要设置以下环境变量：

`LC_ALL=zh_CN.UTF-8`

如果添加多个mod，将它们输入到一个数组中，以`|`分隔，例如`DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## 警告词

一些基础图像上的这个 mod 是巨大的，（数百 megs 压缩演出未压缩）。 它不会过滤到所需的特定语言，而是为非英语用户准备的。 根据您的连接速度/质量，这意味着首次安装初始化可能需要一些时间，区域设置生成也是如此。 预计 5-15 分钟。 一旦完成并在随后的重新启动时，它将不会重新运行，因为逻辑会检查其自身是否存在于文件系统上，但在升级或完整的容器重建时，它将再次运行。

# 国際化 - フォントと非 en_US 言語サポートを追加するためのすべてのコンテナーの Docker mod

この mod は、イメージにフォントとロケールを追加し、コンテナーの起動時にインストール/更新します。

コンテナーの docker 引数で、環境変数 `DOCKER_MODS=linuxserver/mods:universal-internationalization` を設定します。

この言語では、次の環境変数も設定する必要があります:

`LC_ALL=ja_JP.UTF-8`

複数の mod を追加する場合は、「DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2」のように「|」で区切られた配列に入力します

## 注意事項

一部の基本イメージのこの mod は大規模です (数百メガバイトの圧縮ギグが非圧縮)。 必要な特定の言語に絞り込むことはなく、英語以外のユーザー向けのキャッチ オールとして意図されています。 接続の速度/品質によっては、インストールの最初の初期化に時間がかかることを意味し、ロケールの生成も同様です。 5 ～ 15 分の範囲で期待してください。 ロジックがファイルシステム上にそれ自体が存在するかどうかをチェックするため、完了して以降の再起動時に再実行されることはありませんが、アップグレードまたは完全なコンテナの再作成時に再実行されます。

# 국제화 - 글꼴 및 비 en_US 언어 지원을 추가하기 위한 모든 컨테이너용 Docker 모드<br>

이 모드는 컨테이너 시작 중에 설치/업데이트될 글꼴 및 로케일을 이미지에 추가합니다.<br>

컨테이너의 도커 인수에서 환경 변수 `DOCKER_MODS=linuxserver/mods:universal-internationalization`<br>을 설정합니다.

이 언어의 경우 다음 환경 변수도 설정해야 합니다.<br>

`LC_ALL=ko_KR.UTF-8`

여러 모드를 추가하는 경우 `|`로 구분된 배열에 입력하십시오(예: `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`<br>).

## 경고의 말씀<br>

일부 기본 이미지의 이 모드는 방대합니다(수백 메가의 압축된 공연이 비압축됨). 필요한 특정 언어로 필터링되지 않으며 영어가 아닌 사용자를 위한 포괄적인 의미입니다. 연결 속도/품질에 따라 설치를 위한 첫 번째 초기화에 시간이 걸릴 수 있으며 로케일 생성도 가능합니다. 5-15분 정도 소요됩니다. 일단 완료되고 이후 다시 시작하면 논리가 파일 시스템에서 자신의 존재를 확인하기 때문에 다시 실행되지 않지만 업그레이드 또는 전체 컨테이너 재생성 시 다시 실행됩니다.<br>

# التدويل - تعديل Docker لجميع الحاويات لإضافة خطوط ودعم لغة غير en_US 

يضيف هذا الوضع الخطوط واللغات إلى صورة ، ليتم تثبيتها / تحديثها أثناء بدء الحاوية. 

في وسيطات عامل إرساء الحاوية الخاصة بك ، قم بتعيين متغير بيئة `DOCKER_MODS = linuxserver / mods: internationalization` 

بالنسبة لهذه اللغة ، ستحتاج إلى تعيين متغيرات البيئة التالية أيضًا: 

`LC_ALL=ar_AE.UTF-8`

في حالة إضافة تعديلات متعددة ، أدخلها في مصفوفة مفصولة بـ `|` ، مثل `DOCKER_MODS = linuxserver / mods: internationalization | linuxserver / mods: mod2` 

## كلمة تحذير 

هذا التعديل في بعض الصور الأساسية ضخم ، (مئات الميغا من العربات المضغوطة غير مضغوطة). لا يتم التصفية حسب اللغات المحددة المطلوبة ويقصد به أن يكون بمثابة صيد لجميع المستخدمين غير الإنجليز. اعتمادًا على سرعة / جودة اتصالك ، يعني هذا أن أول بدء للتثبيت قد يستغرق بعض الوقت ، وكذلك إنشاء اللغات. توقع في أي مكان من 5-15 دقيقة. بمجرد الانتهاء وإعادة التشغيل اللاحقة ، لن تتم إعادة تشغيله حيث يتحقق المنطق من وجود نفسه على نظام الملفات ، ولكن عند الترقيات أو إعادة إنشاء الحاوية الكاملة ، سيعمل هذا مرة أخرى. 

# Интернационализация — мод Docker для всех контейнеров для добавления шрифтов и поддержки языков, отличных от en_US

Этот мод добавляет в изображение шрифты и локали, которые будут установлены/обновлены при запуске контейнера.

В аргументах docker вашего контейнера установите переменную среды `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Для этого языка вам также потребуется установить следующие переменные среды:

`LC_ALL=ru_RU.UTF-8`

При добавлении нескольких модов введите их в массив, разделенный символом `|`, например, `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Слово предупреждения

Этот мод на некоторых базовых образах является массивным (сотни мегабайт сжатых гигов без сжатия). Он не фильтрует нужные языки и предназначен для всех пользователей, не владеющих английским языком. В зависимости от скорости/качества вашего соединения это означает, что первая инициализация для установки может занять некоторое время, а также создание локалей. Ожидайте от 5 до 15 минут. После завершения и при последующих перезапусках он не будет запускаться повторно, так как логика проверяет свое присутствие в файловой системе, но при обновлении или полном воссоздании контейнера он будет запускаться снова.

# Internacionalización: mod de Docker para que todos los contenedores agreguen fuentes y compatibilidad con idiomas que no sean en_US

Este mod agrega fuentes y configuraciones regionales a una imagen, para que se instalen o actualicen durante el inicio del contenedor.

En los argumentos de la ventana acoplable de su contenedor, establezca una variable de entorno `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Para este idioma, también deberá configurar las siguientes variables de entorno:

`LC_ALL=es_MX.UTF-8`

Si agrega varias modificaciones, introdúzcalas en una matriz separada por `|`, como `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Palabra de advertencia

Este mod en algunas imágenes base es masivo (cientos de megas de conciertos comprimidos sin comprimir). No se filtra a los idiomas específicos que se necesitan y está pensado como una solución para todos los usuarios que no hablan inglés. Dependiendo de la velocidad/calidad de su conexión, esto significa que la primera inicialización para la instalación puede llevar algo de tiempo, así como la generación de locales. Espere entre 5 y 15 minutos. Una vez finalizado y en los reinicios posteriores, no se volverá a ejecutar, ya que la lógica comprueba su presencia en el sistema de archivos, pero en las actualizaciones o en la recreación completa del contenedor, se ejecutará de nuevo.

# Internationalisierung - Docker-Mod für alle Container zum Hinzufügen von Schriftarten und Unterstützung von nicht en_US-Sprachen

Dieser Mod fügt Schriftarten und Gebietsschemata zu einem Image hinzu, die während des Containerstarts installiert/aktualisiert werden.

Setzen Sie in den Docker-Argumenten Ihres Containers eine Umgebungsvariable `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Für diese Sprache müssen Sie auch die folgenden Umgebungsvariablen setzen:

`LC_ALL=de_DE.UTF-8`

Wenn Sie mehrere Mods hinzufügen, geben Sie sie in einem durch `|` getrennten Array ein, wie z. B. `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Warnung

Dieser Mod auf einigen Basis-Images ist massiv (Hunderte von MB komprimierte Gigs unkomprimiert). Es filtert nicht nach bestimmten Sprachen, die benötigt werden, und ist als Sammelpunkt für nicht englische Benutzer gedacht. Abhängig von der Geschwindigkeit/Qualität Ihrer Verbindung bedeutet dies, dass die erste Initialisierung für die Installation einige Zeit in Anspruch nehmen kann, ebenso wie die Generierung der Gebietsschemas. Rechnen Sie mit 5-15 Minuten. Nach Abschluss und bei nachfolgenden Neustarts wird es nicht erneut ausgeführt, da die Logik prüft, ob es sich selbst im Dateisystem befindet, aber bei Upgrades oder der vollständigen Wiederherstellung des Containers wird es erneut ausgeführt.

# Internationalisation - Mod Docker pour tous les conteneurs pour ajouter des polices et un support de langue non en_US

Ce mod ajoute des polices et des paramètres régionaux à une image, à installer/mettre à jour lors du démarrage du conteneur.

Dans les arguments docker de votre conteneur, définissez une variable d'environnement `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Pour cette langue, vous devrez également définir les variables d'environnement suivantes :

`LC_ALL=fr_FR.UTF-8`

Si vous ajoutez plusieurs mods, entrez-les dans un tableau séparé par `|`, comme `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Mot d'avertissement

Ce mod sur certaines images de base est massif (des centaines de mégas de concerts compressés non compressés). Il ne filtre pas les langues spécifiques nécessaires et est conçu comme un fourre-tout pour les utilisateurs non anglophones. En fonction de la vitesse/qualité de votre connexion, cela signifie que la première initialisation de l'installation peut prendre un certain temps, ainsi que la génération des paramètres régionaux. Attendez-vous entre 5 et 15 minutes. Une fois terminé et lors des redémarrages suivants, il ne sera pas réexécuté car la logique vérifie sa présence sur le système de fichiers, mais lors des mises à niveau ou de la recréation complète du conteneur, cela s'exécutera à nouveau.

# Internationalisering - Docker-mod voor alle containers om lettertypen en niet-en_US-taalondersteuning toe te voegen

Deze mod voegt lettertypen en landinstellingen toe aan een afbeelding, die moeten worden geïnstalleerd/geüpdatet tijdens het starten van de container.

Stel in de docker-argumenten van uw container een omgevingsvariabele in `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Voor deze taal moet u ook de volgende omgevingsvariabelen instellen:

`LC_ALL=nl_NL.UTF-8`

Als u meerdere mods toevoegt, voert u deze in een array in gescheiden door `|`, zoals `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Waarschuwing

Deze mod op sommige basisafbeeldingen is enorm (honderden megs gecomprimeerde optredens ongecomprimeerd). Het filtert niet naar specifieke talen die nodig zijn en is bedoeld als verzamelpunt voor niet-Engelse gebruikers. Afhankelijk van de snelheid/kwaliteit van uw verbinding betekent dit dat de eerste init voor installatie enige tijd kan duren, evenals het genereren van locales. Verwacht ergens tussen de 5 en 15 minuten. Eenmaal voltooid en bij daaropvolgende herstarts zal het niet opnieuw worden uitgevoerd omdat de logica controleert op de aanwezigheid van zichzelf op het bestandssysteem, maar bij upgrades of volledige containerrecreatie zal dit opnieuw worden uitgevoerd.

# Internazionalizzazione: mod Docker per tutti i contenitori per aggiungere caratteri e supporto per lingue non en_US

Questa mod aggiunge caratteri e locali a un'immagine, da installare/aggiornare durante l'avvio del contenitore.

Negli argomenti docker del tuo contenitore, imposta una variabile di ambiente `DOCKER_MODS=linuxserver/mods:universal-internationalization`

Per questa lingua dovrai impostare anche le seguenti variabili d'ambiente:

`LC_ALL=it_IT.UTF-8`

Se aggiungi più mod, inseriscile in un array separato da `|`, ad esempio `DOCKER_MODS=linuxserver/mods:universal-internationalization|linuxserver/mods:mod2`

## Parola di avvertimento

Questa mod su alcune immagini di base è enorme (centinaia di mega giga compressi non compressi). Non filtra le lingue specifiche necessarie ed è inteso come una cattura per tutti gli utenti non inglesi. A seconda della velocità/qualità della tua connessione, ciò significa che il primo init per l'installazione può richiedere del tempo, anche la generazione dei locali. Aspettati ovunque da 5-15 minuti. Una volta terminato e ai successivi riavvii, non verrà eseguito nuovamente poiché la logica verifica la presenza di se stesso sul filesystem, ma durante gli aggiornamenti o la ricreazione del contenitore completo verrà eseguito di nuovo.



# Other languages

The following language locales are also supported: 

```
aa_DJ.UTF-8
aa_ER.UTF-8
aa_ET.UTF-8
af_ZA.UTF-8
am_ET.UTF-8
an_ES.UTF-8
ar_AE.UTF-8
ar_BH.UTF-8
ar_DZ.UTF-8
ar_EG.UTF-8
ar_IN.UTF-8
ar_IQ.UTF-8
ar_JO.UTF-8
ar_KW.UTF-8
ar_LB.UTF-8
ar_LY.UTF-8
ar_MA.UTF-8
ar_OM.UTF-8
ar_QA.UTF-8
ar_SA.UTF-8
ar_SD.UTF-8
ar_SY.UTF-8
ar_TN.UTF-8
ar_YE.UTF-8
as_IN.UTF-8
ast_ES.UTF-8
ayc_PE.UTF-8
az_AZ.UTF-8
be_BY.UTF-8
bem_ZM.UTF-8
ber_DZ.UTF-8
ber_MA.UTF-8
bg_BG.UTF-8
bho_IN.UTF-8
bn_BD.UTF-8
bn_IN.UTF-8
bo_CN.UTF-8
bo_IN.UTF-8
br_FR.UTF-8
brx_IN.UTF-8
bs_BA.UTF-8
byn_ER.UTF-8
ca_AD.UTF-8
ca_ES.UTF-8
ca_FR.UTF-8
ca_IT.UTF-8
crh_UA.UTF-8
csb_PL.UTF-8
cs_CZ.UTF-8
cv_RU.UTF-8
cy_GB.UTF-8
da_DK.UTF-8
de_AT.UTF-8
de_BE.UTF-8
de_CH.UTF-8
de_DE.UTF-8
de_LU.UTF-8
doi_IN.UTF-8
dv_MV.UTF-8
dz_BT.UTF-8
el_CY.UTF-8
el_GR.UTF-8
en_AG.UTF-8
en_AU.UTF-8
en_BW.UTF-8
en_CA.UTF-8
en_DK.UTF-8
en_GB.UTF-8
en_HK.UTF-8
en_IE.UTF-8
en_IN.UTF-8
en_NG.UTF-8
en_NZ.UTF-8
en_PH.UTF-8
en_SG.UTF-8
en_US.UTF-8
en_ZA.UTF-8
en_ZM.UTF-8
en_ZW.UTF-8
es_AR.UTF-8
es_BO.UTF-8
es_CL.UTF-8
es_CO.UTF-8
es_CR.UTF-8
es_CU.UTF-8
es_DO.UTF-8
es_EC.UTF-8
es_ES.UTF-8
es_GT.UTF-8
es_HN.UTF-8
es_MX.UTF-8
es_NI.UTF-8
es_PA.UTF-8
es_PE.UTF-8
es_PR.UTF-8
es_PY.UTF-8
es_SV.UTF-8
es_US.UTF-8
es_UY.UTF-8
es_VE.UTF-8
et_EE.UTF-8
eu_ES.UTF-8
fa_IR.UTF-8
ff_SN.UTF-8
fi_FI.UTF-8
fil_PH.UTF-8
fo_FO.UTF-8
fr_BE.UTF-8
fr_CA.UTF-8
fr_CH.UTF-8
fr_FR.UTF-8
fr_LU.UTF-8
fur_IT.UTF-8
fy_DE.UTF-8
fy_NL.UTF-8
ga_IE.UTF-8
gd_GB.UTF-8
gez_ER.UTF-8
gez_ET.UTF-8
gl_ES.UTF-8
gu_IN.UTF-8
gv_GB.UTF-8
ha_NG.UTF-8
he_IL.UTF-8
hi_IN.UTF-8
hne_IN.UTF-8
hr_HR.UTF-8
hsb_DE.UTF-8
ht_HT.UTF-8
hu_HU.UTF-8
hy_AM.UTF-8
ia_FR.UTF-8
id_ID.UTF-8
ig_NG.UTF-8
ik_CA.UTF-8
is_IS.UTF-8
it_CH.UTF-8
it_IT.UTF-8
iu_CA.UTF-8
ja_JP.UTF-8
ka_GE.UTF-8
kk_KZ.UTF-8
kl_GL.UTF-8
km_KH.UTF-8
kn_IN.UTF-8
kok_IN.UTF-8
ko_KR.UTF-8
ks_IN.UTF-8
ku_TR.UTF-8
kw_GB.UTF-8
ky_KG.UTF-8
lb_LU.UTF-8
lg_UG.UTF-8
li_BE.UTF-8
lij_IT.UTF-8
li_NL.UTF-8
lo_LA.UTF-8
lt_LT.UTF-8
lv_LV.UTF-8
mag_IN.UTF-8
mai_IN.UTF-8
mg_MG.UTF-8
mhr_RU.UTF-8
mi_NZ.UTF-8
mk_MK.UTF-8
ml_IN.UTF-8
mni_IN.UTF-8
mn_MN.UTF-8
mr_IN.UTF-8
ms_MY.UTF-8
mt_MT.UTF-8
my_MM.UTF-8
nb_NO.UTF-8
nds_DE.UTF-8
nds_NL.UTF-8
ne_NP.UTF-8
nhn_MX.UTF-8
niu_NU.UTF-8
niu_NZ.UTF-8
nl_AW.UTF-8
nl_BE.UTF-8
nl_NL.UTF-8
nn_NO.UTF-8
nr_ZA.UTF-8
nso_ZA.UTF-8
oc_FR.UTF-8
om_ET.UTF-8
om_KE.UTF-8
or_IN.UTF-8
os_RU.UTF-8
pa_IN.UTF-8
pa_PK.UTF-8
pl_PL.UTF-8
ps_AF.UTF-8
pt_BR.UTF-8
pt_PT.UTF-8
ro_RO.UTF-8
ru_RU.UTF-8
ru_UA.UTF-8
rw_RW.UTF-8
sa_IN.UTF-8
sat_IN.UTF-8
sc_IT.UTF-8
sd_IN.UTF-8
se_NO.UTF-8
shs_CA.UTF-8
sid_ET.UTF-8
si_LK.UTF-8
sk_SK.UTF-8
sl_SI.UTF-8
so_DJ.UTF-8
so_ET.UTF-8
so_KE.UTF-8
so_SO.UTF-8
sq_AL.UTF-8
sq_MK.UTF-8
sr_ME.UTF-8
sr_RS.UTF-8
ss_ZA.UTF-8
st_ZA.UTF-8
sv_FI.UTF-8
sv_SE.UTF-8
sw_KE.UTF-8
sw_TZ.UTF-8
szl_PL.UTF-8
ta_IN.UTF-8
ta_LK.UTF-8
te_IN.UTF-8
tg_TJ.UTF-8
th_TH.UTF-8
ti_ER.UTF-8
ti_ET.UTF-8
tig_ER.UTF-8
tk_TM.UTF-8
tl_PH.UTF-8
tn_ZA.UTF-8
tr_CY.UTF-8
tr_TR.UTF-8
ts_ZA.UTF-8
tt_RU.UTF-8
ug_CN.UTF-8
uk_UA.UTF-8
unm_US.UTF-8
ur_IN.UTF-8
ur_PK.UTF-8
uz_UZ.UTF-8
ve_ZA.UTF-8
vi_VN.UTF-8
wa_BE.UTF-8
wae_CH.UTF-8
wal_ET.UTF-8
wo_SN.UTF-8
xh_ZA.UTF-8
yi_US.UTF-8
yo_NG.UTF-8
yue_HK.UTF-8
zh_CN.UTF-8
zh_HK.UTF-8
zh_SG.UTF-8
zh_TW.UTF-8
zu_ZA.UTF-8
```

