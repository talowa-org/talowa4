// Comprehensive Test Suite for Enhanced Feed System
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../lib/services/social_feed/enhanced_feed_service.dart';
import '../lib/models/social_feed/post_model.dart';
import '../lib/models/social_feed/comment_model.dart';

// Mock classes
class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
class MockCollectionReference extends Mock implements CollectionReference {}
class MockDocumentReference extends Mock implements DocumentReference {}
class MockQuerySnapshot extends Mock implements QuerySnapshot {}
class MockDocumentSnapshot extends Mock implements DocumentSnapshot {}

void main() {
  group('Enhanced Feed Service Tests', () {
    late EnhancedFeedService feedService;
    late MockFirebaseFirestore mockFirestore;
    late MockCollectionReference mockCollection;
    late MockDocumentReference mockDocument;

    setUp(() {
      mockFirestore = MockFirebaseFirestore();
      mockCollection = MockCollectionReference();
      mockDocument = MockDocumentReference();
      feedService = EnhancedFeedService();
    });

    group('Feed Loading Tests', () {
      test('should load feed posts successfully', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        final mockDocs = <MockDocumentSnapshot>[];
        
        // Create mock post data
        final postData = {
          'id': 'test_post_1',
          'authorId': 'user_1',
          'authorName': 'Test User',
          'content': 'Test post content',
          'createdAt': Timestamp.now(),
          'likesCount': 5,
          'commentsCount': 2,
          'sharesCount': 1,
          'hashtags': ['test', 'flutter'],
          'category': 'general_discussion',
          'location': 'Test Location',
          'imageUrls': [],
          'videoUrls': [],
          'documentUrls': [],
        };

        final mockDoc = MockDocumentSnapshot();
        when(mockDoc.id).thenReturn('test_post_1');
        when(mockDoc.data()).thenReturn(postData);
        when(mockDoc.exists).thenReturn(true);
        mockDocs.add(mockDoc);

        when(mockSnapshot.docs).thenReturn(mockDocs);
        when(mockCollection.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockCollection);
        when(mockCollection.limit(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockSnapshot);
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);

        // Act
        final posts = await feedService.getFeedPosts(limit: 10);

        // Assert
        expect(posts, isNotEmpty);
        expect(posts.length, equals(1));
        expect(posts.first.id, equals('test_post_1'));
        expect(posts.first.content, equals('Test post content'));
        expect(posts.first.hashtags, contains('test'));
      });

      test('should handle empty feed gracefully', () async {
        // Arrange
        final mockSnapshot = MockQuerySnapshot();
        when(mockSnapshot.docs).thenReturn([]);
        when(mockCollection.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockCollection);
        when(mockCollection.limit(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenAnswer((_) async => mockSnapshot);
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);

        // Act
        final posts = await feedService.getFeedPosts(limit: 10);

        // Assert
        expect(posts, isEmpty);
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        when(mockCollection.orderBy(any, descending: anyNamed('descending')))
            .thenReturn(mockCollection);
        when(mockCollection.limit(any)).thenReturn(mockCollection);
        when(mockCollection.get()).thenThrow(Exception('Network error'));
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);

        // Act & Assert
        expect(
          () => feedService.getFeedPosts(limit: 10),
          throwsException,
        );
      });
    });

    group('Post Creation Tests', () {
      test('should create post successfully', () async {
        // Arrange
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);
        when(mockCollection.doc()).thenReturn(mockDocument);
        when(mockDocument.id).thenReturn('new_post_id');
        when(mockDocument.set(any)).thenAnswer((_) async => {});

        // Mock user document
        final mockUserDoc = MockDocumentSnapshot();
        when(mockUserDoc.exists).thenReturn(true);
        when(mockUserDoc.data()).thenReturn({
          'fullName': 'Test User',
          'role': 'member',
          'address': {'villageCity': 'Test City'},
        });

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.get()).thenAnswer((_) async => mockUserDoc);

        // Act
        final postId = await feedService.createPost(
          content: 'Test post content',
          title: 'Test Title',
          hashtags: ['test'],
        );

        // Assert
        expect(postId, equals('new_post_id'));
      });

      test('should validate post content', () async {
        // Act & Assert
        expect(
          () => feedService.createPost(content: ''),
          throwsException,
        );

        expect(
          () => feedService.createPost(content: 'a' * 5001),
          throwsException,
        );
      });

      test('should extract hashtags from content', () async {
        // This would test the private _extractHashtags method
        // In a real implementation, you might make it public for testing
        // or test it indirectly through createPost
        
        // Arrange
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);
        when(mockCollection.doc()).thenReturn(mockDocument);
        when(mockDocument.id).thenReturn('new_post_id');
        when(mockDocument.set(any)).thenAnswer((_) async => {});

        final mockUserDoc = MockDocumentSnapshot();
        when(mockUserDoc.exists).thenReturn(true);
        when(mockUserDoc.data()).thenReturn({
          'fullName': 'Test User',
          'role': 'member',
        });

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.get()).thenAnswer((_) async => mockUserDoc);

        // Act
        await feedService.createPost(
          content: 'This is a test post with #hashtag1 and #hashtag2',
        );

        // Assert
        // Verify that the post was created with extracted hashtags
        verify(mockDocument.set(argThat(predicate<Map<String, dynamic>>((data) {
          final hashtags = data['hashtags'] as List<String>?;
          return hashtags != null && 
                 hashtags.contains('hashtag1') && 
                 hashtags.contains('hashtag2');
        })))).called(1);
      });
    });

    group('Engagement Tests', () {
      test('should toggle like successfully', () async {
        // Arrange
        final mockTransaction = MockTransaction();
        when(mockFirestore.runTransaction(any))
            .thenAnswer((invocation) async {
          final transactionFunction = invocation.positionalArguments[0] as Function;
          return await transactionFunction(mockTransaction);
        });

        // Mock like document (doesn't exist - so we're liking)
        final mockLikeDoc = MockDocumentSnapshot();
        when(mockLikeDoc.exists).thenReturn(false);
        when(mockTransaction.get(any)).thenAnswer((_) async => mockLikeDoc);

        // Mock post document
        final mockPostDoc = MockDocumentSnapshot();
        when(mockPostDoc.exists).thenReturn(true);

        when(mockFirestore.collection('post_likes')).thenReturn(mockCollection);
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDocument);

        // Act
        await feedService.toggleLike('test_post_id');

        // Assert
        verify(mockTransaction.set(any, any)).called(1);
        verify(mockTransaction.update(any, any)).called(1);
      });

      test('should add comment successfully', () async {
        // Arrange
        when(mockFirestore.collection('post_comments')).thenReturn(mockCollection);
        when(mockFirestore.collection('posts')).thenReturn(mockCollection);
        when(mockCollection.doc()).thenReturn(mockDocument);
        when(mockCollection.doc(any)).thenReturn(mockDocument);
        when(mockDocument.id).thenReturn('new_comment_id');
        when(mockDocument.set(any)).thenAnswer((_) async => {});
        when(mockDocument.update(any)).thenAnswer((_) async => {});

        // Mock user document
        final mockUserDoc = MockDocumentSnapshot();
        when(mockUserDoc.exists).thenReturn(true);
        when(mockUserDoc.data()).thenReturn({
          'fullName': 'Test User',
          'role': 'member',
        });
        when(mockDocument.get()).thenAnswer((_) async => mockUserDoc);

        // Ac
}}
  e');dicatrees pd('matchcription.ad return deson) {
   on descriptiescriptiribe(Diption desccre
  Des
  @overridem);
  }
&& _test(its T em iturn it  re) {
  p matchState Mam,dynamic itel matches(ide
  boo @overr

 this._test);tcher(ateMaedic

  _PrT) _test;tion(ol Funcinal bo {
  f Matcher<T> extendscateMatcher_Prediass 
clst);
<T>(teMatchercate> _Preditest) =nction(T) T>(bool Fudicate< pre
Matcherate matchersreate predic con tolper functi He
//
ion {} Transacttsimplemen Mock endsextction Transaockass M classes
clitional mock
// Add);
}
 });
  }   ee
can sordinators // CosTrue); nator'), ile: 'coordiuserRoer_user', erId: 'othusser(sibleToUnt.isVit(comme    expecn
  see hiddeannot Others clse); // er'), isFa: 'other_usser(userIdibleToUismment.isVexpect(coee
      or can suthrue); // A isTauthor_id'),d: 'rIsebleToUser(unt.isVisiect(commet
      expsser // Act & A

     
      );,ue trsHidden:  i,
      eTime.now()atdAt: D  create
      nt',t commentent: 'Tes
        co'Author',uthorName: 
        a,hor_id' 'aututhorId:       ast_id',
 ostId: 'po
        pomment_id', id: 'c
       odel(CommentM = al comment      finrange
 // Ar
      () {y',rectlsibility cord check vist('shoul   te
     });
, isNull);
comment')('Valid idateContententModel.valt(Comm
      expeccters'));hara 500 cnnot exceedment caequals('Com), t('a' * 501Contenteidaodel.val(CommentMect exp;
     be empty'))annot nt cComme), equals('eContent(''atodel.validCommentM    expect(
  rtse // Act & As     ) {
ent', (comment contte validauld ho  test('s{
  ts', () el Tesomment Modroup('C});

  g
    });
  quals(4));th, eiaUrls.lengpost.allMedexpect(
      4));nt, equals(ouotalMediaCect(post.texpue);
      edia, isTrasMt(post.h
      expecTrue);nts, isDocumeast(post.h
      expecTrue);Videos, isost.hasct(p     expeTrue);
 sImages, ishaect(post.      expAssert
  // Act & 
      );
    ,
lse: faUserrrentkedByCu       isLi
 ount: 0,resC  sha 0,
      tsCount:ommen      count: 0,
        likesC.now(),
  ateTimereatedAt: D   c: '',
     cation   lo
     n,siousgeneralDiscory.stCategegory: Po  cat
      ashtags: [],      h
  df'],doc1.pentUrls: ['docum     4'],
   eo1.mpUrls: ['vid  video     e2.png'],
  'image1.jpg',s: ['imagimageUrl       ontent',
 ent: 'Test c cont,
       Test Author'e: 'rNamtho
        auor_id',auth: 'Iduthor     a',
   d: 'test_id     iel(
   odpost = PostM      final ange
/ Arr /{
     ctly', () URLs corredia andle mest('should h
    te
    });
y));Post.categors(original equalategory,ost.clizedP(deseria      expect);
st.hashtags)nalPogiuals(orihtags, eq.hasdPosterializect(des    expetent));
  lPost.conls(originaent, equat.contalizedPoseriexpect(desd));
      uthorInalPost.als(origiuathorId, eqlizedPost.auct(deseria     expeid));
 iginalPost.(or.id, equalslizedPosteseria expect(d   
  ssert
      // AckDoc);
(mooreomFirestPostModel.frlizedPost =  deseria
      final      
eData);n(firestor).thenReturdata()ckDoc. when(mod);
     Post.iiginalrn(or).thenRetumockDoc.idhen(
      w();shotDocumentSnap= MockmockDoc     final ot
  apshent snock docum Create a m  // 
    ;
     restore()t.toFiginalPosData = orial firestore      fin  // Act
   ;

      )alse,
  fser:yCurrentU   isLikedBt: 1,
      sharesCoun       2,
Count: mments     cont: 5,
   kesCou       li,
 me.now()ateTit: DeatedA    crtion',
    'Test Loca:   location
      ssion,ralDiscuneory.geostCateg: Poryteg       ca'],
 tter 'flu['test',hashtags: 
        t',t contenTesntent: '      cor',
  uthoe: 'Test ArNam      autho  id',
Id: 'author_      authort_id',
     id: 'tes  l(
   Modest= PonalPost final origige
      rran
      // Actly', () {ore correFirestfrom and lize to seria('should  {
    test ()l Tests',t Modeup('Pos
  gro});
   });
      });
 n
   injectioependency using dtics oratisg cache stposinuire exwould req    // This d once
     only callewasase atabe dhat thfy t'd veriion, youatementpl real im    // In aert
     // Ass
       : true);
eCachet: 10, uss(limiedPostgetFervice.it feedSe        awaue);
: tr0, useCachets(limit: 1tFeedPosService.geawait feed       
       // Act  on);

ollecti(mockC.thenReturn('posts'))tionolleckFirestore.cen(moc
        whhot);=> mockSnaps(_) async wer()).thenAnsction.get(ockColle(mwhen        n);
ectiockCollturn(mony)).thenReion.limit(aCollectn(mock whe;
       llection)(mockCoReturnthen   .        
 ')))ndinged('desceanyNamng:  descendiy,rBy(ann.ordetioockCollec   when(m);
     n([]eturhenR).tot.docsapshSnock(men        whnapshot();
ockQuerySot = Ml mockSnapsh        finarrange
       // A   
 calls
     se  databae, reducingvailabl // when a    s
   ched resultcaice uses hat the servrify tst would ve  // This te {
       () asyncavailable',sults when se cached re('should utest     
 () {g Tests', achin    group('C);


    };
      });    ))),
    ion>(outExceptsA(isA<Time    throw,
      s: 5))econd(st Durationt(cons.timeous()edPostervice.getFe=> feedS  ()      ect(
     exp     
 & Assert     // Act on);

   ckCollectihenReturn(mos')).tsttion('potore.collec(mockFires     when  );
 
        }ds: 30));econ Duration(s, const timeout'on('RequestExcepti Timeout      throw 30));
    seconds:ion((const Durateduture.delay F     await     sync {
(_) aswer().thenAnon.get()ckCollecti   when(moe
      // Arrang
       () async {ts', work timeoudle net hanuld('sho  test);

         }
         );),
eption>()seExcba(isA<Fire   throwsA
       dPosts(),ce.getFeeeedServi() => f         
 ct(    expeert
    ct & Ass     // A      );

    ),
    e',
        unavailablervice: 'S   message         ble',
 'unavaila  code:     re',
     loud_firestogin: 'c      plu      ption(
baseExce       Fire  Throw(
 en).thon('posts')ore.collectiirestwhen(mockF     
   range      // Ar {
   () asynccefully',raeptions ge excestor Firdleshould han     test('{
 ()  Tests', Handlingroup('Error 

    g);
    });
      }2 seconds/ Less than 0)); /200Than(lessnds, edMillisecolapstch.epect(stopwa     ex(100));
   ualsgth, eqs.lenst expect(po
       sert      // As  ();

ch.stop    stopwat;
    limit: 100)tFeedPosts(geervice.await feedSal posts =   fin();
      rtwatch()..staop= St stopwatch final
         // Act  ;

     lection)rn(mockColhenRetu).tsts')'poollection(kFirestore.cwhen(moc       apshot);
 kSnmoc async => ((_)henAnswer)).tion.get(ectmockCollhen(        w;
ection)lleturn(mockConR)).theit(anyimtion.lckCollecn(mo whe;
       n)ctioolle(mockCeturn     .thenR))
       ')escending('danyNamedescending: y, dy(anon.orderBCollectimock       when(s);
 Docrn(largeMocks).thenRetudocshot.(mockSnap     when  });

      
   ckDoc; morn      retu
            });ls': [],
  'documentUr          [],
  rls': videoU '           Urls': [],
  'image          ndex',
on $i: 'Locatition'  'loca          
iscussion',ral_dgory': 'gene   'cate       '],
  dex': ['tag$in   'hashtags        dex % 3,
 Count': in 'shares      ,
     : index % 5ount'ntsC     'comme       t': index,
esCoun    'lik  
      w(),p.noam': TimestatedAt'cre           ,
 ex'ost $indt for pontenontent': 'C  'c        $index',
  ': 'User mehorNa     'aut  ',
     ex_$indorId': 'user    'auth,
        $index'': 'post_ 'id      urn({
     Ret).thena().dat(mockDoc    when
      ex');$indeturn('post_.id).thenRocen(mockD  wh     hot();
   napsumentSoc = MockDocckD    final mo  
     { (index)(100,rate.genekDocs = Listl largeMoc        finat();
ySnapshouerockQapshot = Mal mockSn        finge
an // Arr    async {
   ly', () ntets efficiee datas largle'should handest(

      t   });cond
   1 seLess than )); // han(1000lessTlliseconds, elapsedMi(stopwatch.    expectt
     // Asser;

       .stop()chstopwat         20);
sts(limit:getFeedPodService.wait fee
        art();..statopwatch()watch = Sfinal stop       ct
     // A  

  ollection);n(mockCthenRetur)).('posts'.collectionockFirestore   when(m
     });        apshot;
eturn mockSn     r;
     100))econds: on(millisDuratinst elayed(co Future.dawait          ork delay
twmulate ne    // Si {
      ((_) async).thenAnswer().gettionkCollecmoc     when(
   on);ti(mockCollecrnenRetumit(any)).thllection.li(mockCoen wh);
       tionollecockCrn(metu    .thenR))
        ing')descendnyNamed('escending: aerBy(any, dtion.ordCollec  when(mock]);
      urn([thenRett.docs).napshoockS      when(m  apshot();
rySnckQueshot = Monal mockSnap     fi  ge
    // Arran
     c {asyn) e time', ( acceptablhinoad witeed lomplete fhould ct('s   tes) {
   s', (estmance Toup('Perfor
    gr;

    })  });mpty);
    ts, isEsul  expect(re      / Assert


        /;nexistent')(query: 'nostshPo.searcvicefeedSerwait esults = al rinat
        f// Ac      tion);

  mockCollecurn(nRet.the'posts'))ection(store.colln(mockFire  whet);
      ockSnapsho) async => mwer((_()).thenAns.getllectionmockCowhen(   ;
     ection)ollurn(mockCnRet(any)).thection.limitockColle     when(m
   ollection);(mockCenReturn      .th
      g')))('descendin anyNamedcending:y(any, desderBion.orectkColl    when(moc]);
    ([henReturncs).tdot.ckSnapsho  when(mot();
      QuerySnapshoot = MockmockSnapsh    final      Arrange
      //sync {
  ', () ahesno matcor ty results f empturnuld resho test('
      });
m'));
     ('search terontains, contents.first.cect(result   exp
     otEmpty); isNect(results,exp
         Assert       //

 ch term');aruery: 'sePosts(qearcheedService.s faitresults = awinal t
        f  // Ac   ion);

   ollectckCReturn(mo')).thenion('postse.collectirestor  when(mockF;
      Snapshot) mockync =>wer((_) as).thenAnsection.get()kColl   when(moc
     ction);(mockColle).thenReturnt(any).limillectionn(mockCohe      wction);
  rn(mockColle .thenRetu   
        scending')))ed('deng: anyNamescendierBy(any, dection.ordollockCn(mwhe      ]);
  urn([mockDocetthenRot.docs).(mockSnapshhen    w});

       
     tUrls': [],    'documen[],
      rls':   'videoU     [],
   rls': imageU
          ',: ''n'ocatio          'lssion',
eral_discugory': 'gen'cate      ,
     []'hashtags':         unt': 0,
 sCo      'share': 0,
    tsCount    'commen
      0,: ount' 'likesC      
   .now(),: TimestampeatedAt'        'crrm',
  ch te the searntainsThis post cot': '     'conten',
     t User'TeshorName':   'aut        r_1',
'usethorId':     'au',
      ost_1earch_p: 's   'id'    turn({
   .thenRe())c.data(mockDohen;
        wt_1')('search_posthenReturnid).Doc. when(mock 
       
       );ntSnapshot(ocumeMockD = ocfinal mockD        shot();
Snap= MockQuerypshot Snal mock      finage
    // Arran     
  async { query', ()sts byld search poest('shou t () {
     s',arch Testup('Se

    gro);
    });   }   );
   on,
     sExceptithrow
             ),    501,
     *: 'a'   content
         ost_id',est_pstId: 't  po          dComment(
e.aderviceedS() => f         pect(
         ex   );


     xception,   throwsE       ,
  )        '',
     content:',
        ost_id 'test_postId:         pent(
   vice.addCommeredS  () => fe       expect(
 rt
         Act & Asse //      {
  async nt', ()temment condate coould vali  test('sh       });

  t_id'));
 ommen_cewequals('nmentId, (compectexrt
        sse A//          );

  ',
    commentst ntent: 'Te        cost_id',
  _potest 'd: postI
         omment(ervice.addCeedSId = await fmmentfinal co     t
   