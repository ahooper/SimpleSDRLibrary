//
//  FIRFilterTests.swift
//  SimpleSDR3Tests
//
//  Test data from liquid-dsp-1.3.1/src/filter/tests/data/firfilt_?r?f_data_h*x*.c
//
//  Created by Andy Hooper on 2019-12-15.
//  Copyright © 2019 Andy Hooper. All rights reserved.
//

import XCTest
import struct Accelerate.vecLib.vDSP.DSPComplex
@testable import SimpleSDRLibrary

class FIRFilterTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    fileprivate func runTest(_ h: [Float], _ x: [Float], _ y: [Float]) {
        // Test on the whole block
        let f = FIRFilter(source:SourceBox<RealSamples>.NilReal(), h)
        var o=RealSamples()
        f.process(RealSamples(x), &o)
        AssertEqual(o, y, accuracy:5.0e-8)
        
        // Test on two halves in sequence, to exercise stream overalap
        let f2 = FIRFilter(source:SourceBox<RealSamples>.NilReal(), h)
        let half = x.count / 2
        var oo=RealSamples(), o2=RealSamples()
        f2.process(RealSamples(Array(x[0..<half])), &oo)
        f2.process(RealSamples(Array(x[half...])), &o2)
        oo.append(o2)
        AssertEqual(oo, y, accuracy:5.0e-8)
        
        // Test on individual samples, to exercise stream overalap
        let f3 = FIRFilter(source:SourceBox<RealSamples>.NilReal(), h)
        var o3 = RealSamples()
        oo.removeAll()
        for i in 0..<x.count {
            f3.process(RealSamples(Array(x[i...i])), &o3)
            oo.append(o3)
        }
        AssertEqual(oo, y, accuracy:5.0e-8)
        AssertEqual(oo, Array(o[0..<o.count]), accuracy: 0.0)
    }
    
    fileprivate func runTest(_ h: [Float], _ x: [DSPComplex], _ y: [DSPComplex]) {
        // Test on the whole block
        let f = FIRFilter(source:SourceBox<ComplexSamples>.NilComplex(), h)
        var o=ComplexSamples()
        f.process(ComplexSamples(x), &o)
        AssertEqual(o, y, accuracy:1.0e-7)
        
        // Test on two halves in sequence, to exercise stream overalap
        let f2 = FIRFilter(source:SourceBox<ComplexSamples>.NilComplex(), h)
        let half = x.count / 2
        var oo=ComplexSamples(), o2=ComplexSamples()
        f2.process(ComplexSamples(Array(x[0..<half])), &oo)
        f2.process(ComplexSamples(Array(x[half...])), &o2)
        oo.append(o2)
        AssertEqual(oo, y, accuracy:1.0e-7)
    }

    func testFIRFilter_h4x8() {
        let h4:[Float] = [
           -0.121887159208,
           -0.231303112477,
           -0.011081038093,
            0.002940945390]
        let x8:[Float] = [
            0.087523073427,
            0.091626543082,
            0.069905988906,
           -0.025530671018,
           -0.085926435885,
            0.016121796124,
            0.067241716218,
            0.036151454364]
        let y8:[Float] = [
           -0.010667938785,
           -0.031412458342,
           -0.030683993510,
           -0.013815528486,
            0.015873490575,
            0.018398508167,
           -0.011047853592,
           -0.020390967516]
        runTest(h4, x8, y8)
    }
    
    func testFIRFilter_h7x16() {
        let h7:[Float] = [
             0.167653994833,
             0.011522192990,
             0.015882599202,
            -0.093561396312,
             0.074301353348,
            -0.124295601121,
             0.032095823166]
        let x16:[Float] = [
             0.096678620741,
             0.015023630036,
             0.051530016668,
            -0.094237043292,
             0.007423744308,
             0.024664429619,
            -0.199548815687,
             0.003258035222,
             0.082829872734,
             0.142277057992,
            -0.149671886106,
            -0.058687993370,
             0.018936199920,
            -0.026660942281,
             0.016612364911,
             0.178689105006]
        let y16:[Float] = [
             0.016208556982,
             0.003632721318,
             0.010347826097,
            -0.024012250428,
             0.006754954149,
            -0.012997772766,
            -0.019171751321,
            -0.014980556455,
             0.022366048926,
             0.041414757082,
            -0.040097174540,
             0.008782967641,
            -0.013845574916,
             0.009200324306,
            -0.017877119698,
             0.046763669812]
        runTest(h7, x16, y16)
    }
    
    func testFIRFilter_h13x32() {
        let h13:[Float] = [
             0.061701400663,
            -0.003256845257,
             0.085737504490,
            -0.119088464421,
            -0.094195167190,
            -0.035614627393,
            -0.075640421976,
            -0.178180567927,
             0.062656377018,
             0.024575001277,
             0.158593583928,
             0.002228379520,
             0.112351904789]
        let x32:[Float] = [
            -0.020470493148,
             0.102018118476,
            -0.054985718021,
             0.006308577753,
            -0.136776277914,
            -0.097553343057,
             0.015106021667,
            -0.115276028482,
            -0.139555063727,
            -0.008140535272,
             0.149942052537,
            -0.011892278070,
             0.065230575705,
             0.142075094351,
            -0.164907789585,
            -0.032484693281,
            -0.096276951150,
             0.147981941286,
            -0.058167278365,
             0.122586631059,
            -0.085249376452,
            -0.044902927900,
             0.078432553797,
             0.057861317911,
            -0.063852807160,
            -0.049949958624,
            -0.041909155283,
            -0.022591033341,
             0.048035976026,
             0.022495836486,
            -0.073843897589,
             0.112675367305]
        let y32:[Float] = [
            -0.001263058100,
             0.006361330031,
            -0.005480042042,
             0.011752906544,
            -0.023395131780,
            -0.007365237036,
            -0.008133908376,
            -0.001942584790,
             0.002035200118,
             0.017539310799,
             0.018129651215,
             0.071947442682,
             0.032171241395,
             0.004309016586,
            -0.015673178031,
             0.002288611018,
            -0.077270639492,
            -0.048373764758,
            -0.012295934305,
             0.006856074159,
            -0.019007594657,
             0.044313034038,
             0.016681139459,
             0.021356291565,
            -0.035698344648,
             0.018453059195,
            -0.069848287101,
             0.038262898124,
            -0.010626132241,
             0.023942333214,
            -0.013545270316,
             0.034191460826]
        runTest(h13, x32, y32)
    }
    
    func testFIRFilter_h23x64() {
        let h23:[Float] = [
             0.023507854506,
             0.027103933172,
             0.106752895472,
             0.074063587060,
             0.012575431714,
            -0.014208904360,
            -0.189995720602,
             0.034113160679,
             0.175609922460,
             0.105200934542,
            -0.005136522642,
            -0.005531746670,
             0.139731146359,
            -0.079842377920,
            -0.233214917226,
             0.035638281722,
            -0.163205439104,
            -0.032478500610,
             0.199430113992,
             0.220129425730,
            -0.036005167889,
             0.056409106456,
            -0.004421322176]
        let x64:[Float] = [
            -0.013049061997,
             0.119281727724,
            -0.119365267096,
             0.039835879910,
            -0.009513587246,
             0.082243762515,
             0.027956820983,
            -0.069085027701,
             0.052848019057,
             0.146020985374,
             0.037417929487,
            -0.084232021180,
            -0.009683296201,
            -0.090624445719,
            -0.006075254980,
             0.165633370941,
            -0.073874907410,
             0.017988275377,
             0.070181770610,
            -0.244164921762,
            -0.038716233769,
             0.076498331411,
            -0.013031514838,
            -0.213155932917,
            -0.027341233086,
            -0.146873071789,
            -0.026995500788,
            -0.072655809839,
             0.156894258163,
             0.124930378658,
             0.056420922814,
             0.134062816355,
            -0.086478418152,
             0.065523216564,
            -0.081200039055,
             0.011086704550,
             0.085758668011,
             0.132499850065,
             0.054287271241,
             0.057554900510,
            -0.022403923256,
             0.244428874813,
             0.084740945011,
             0.112048571173,
            -0.245511705590,
             0.030473857673,
            -0.089496518267,
             0.112146468923,
            -0.038155919073,
            -0.079948318739,
             0.081965047586,
             0.060785574587,
            -0.015596830096,
             0.062834032397,
            -0.138572554778,
             0.183714729747,
             0.046778584717,
            -0.046081790098,
            -0.074463177805,
            -0.206183023427,
             0.125672790474,
             0.071969502765,
             0.088478692161,
            -0.118547492713]
        let y64:[Float] = [
            -0.000306755451,
             0.002450376596,
            -0.000966042507,
             0.009468397319,
            -0.003216187841,
            -0.001227073462,
             0.004104453009,
            -0.013702311097,
             0.032216367463,
             0.008663721625,
            -0.000634352930,
            -0.004782446546,
             0.012088802412,
             0.038158275560,
            -0.033642624259,
            -0.056941408268,
             0.025461989933,
             0.042996863950,
             0.042722153417,
            -0.013343258900,
            -0.002992404220,
            -0.070410666038,
            -0.020716833687,
            -0.012052257283,
             0.015366009966,
            -0.010804920764,
            -0.018064798938,
             0.027733552912,
            -0.024577324228,
             0.020395693321,
             0.044679445466,
            -0.071992656961,
            -0.028274328337,
             0.109882255190,
            -0.054423216252,
            -0.062518613459,
             0.073109299563,
            -0.001030697779,
             0.000264209985,
             0.117080616804,
             0.074883914872,
             0.008816712343,
            -0.093804636161,
            -0.024674797173,
            -0.069634193023,
            -0.015132328421,
             0.010801011890,
            -0.019904446976,
             0.054767171785,
             0.070007069212,
             0.098407344602,
            -0.023208041689,
            -0.034398540605,
            -0.056178855164,
             0.015638332591,
             0.011048505195,
            -0.032658159097,
            -0.031311550317,
             0.061445928366,
             0.033547250971,
             0.134751463913,
            -0.058463369920,
             0.012179813382,
            -0.001597271199]
        runTest(h23, x64, y64)
    }
    
    
    func testFIRFilterComplexReal_h13x32() {
        runTest(firfilt_crcf_data_h13x32_h,
                firfilt_crcf_data_h13x32_x,
                firfilt_crcf_data_h13x32_y)
        }
        
    func testFIRFilterComplexReal_h23x64() {
        runTest(firfilt_crcf_data_h23x64_h,
                firfilt_crcf_data_h23x64_x,
                firfilt_crcf_data_h23x64_y)
        }
        
    func testFIRFilterComplexReal_h4x8() {
        runTest(firfilt_crcf_data_h4x8_h,
                firfilt_crcf_data_h4x8_x,
                firfilt_crcf_data_h4x8_y)
        }
        
    func testFIRFilterComplexReal_h7x16() {
        runTest(firfilt_crcf_data_h7x16_h,
                firfilt_crcf_data_h7x16_x,
                firfilt_crcf_data_h7x16_y)
    }
    
    // Complex coefficients is not implemented

    let firfilt_crcf_data_h13x32_h: [Float] = [
        0.005113901796,
        0.005286268339,
       -0.119811540901,
       -0.004501609093,
       -0.065007372397,
        0.048866593324,
        0.013172470077,
       -0.002661385800,
        0.103490232103,
       -0.080549511664,
        0.044381828692,
        0.059428974785,
        0.036011050317]

    let firfilt_crcf_data_h13x32_x = [
       DSPComplex(-0.150478051517,  0.011369787230),
       DSPComplex(-0.011682362019, -0.131898855698),
       DSPComplex( 0.002241423344,  0.056583759593),
       DSPComplex(-0.059449335305,  0.187622651747),
       DSPComplex(-0.180436000741,  0.005303426369),
       DSPComplex( 0.011260126047,  0.058406411239),
       DSPComplex( 0.104607282644,  0.079267822272),
       DSPComplex( 0.085374933204,  0.051946754389),
       DSPComplex(-0.022910313299,  0.030414137098),
       DSPComplex( 0.088237668857, -0.149226301695),
       DSPComplex(-0.077336181799,  0.011213633150),
       DSPComplex(-0.041671694767, -0.010591371244),
       DSPComplex(-0.072827057153,  0.029626684791),
       DSPComplex(-0.031258311706, -0.032641520688),
       DSPComplex(-0.008154356734,  0.089595819254),
       DSPComplex( 0.008874945980,  0.055052307581),
       DSPComplex( 0.021540988384,  0.002343360972),
       DSPComplex( 0.031406241630, -0.041565525378),
       DSPComplex(-0.186621079183, -0.055706611874),
       DSPComplex(-0.204887932486,  0.107546397697),
       DSPComplex(-0.001299342939, -0.091725815207),
       DSPComplex( 0.098883395599, -0.042781095000),
       DSPComplex(-0.148848628287,  0.075959712533),
       DSPComplex( 0.168232372928,  0.044377154144),
       DSPComplex( 0.162761143249, -0.111406681457),
       DSPComplex(-0.069728838323,  0.030195226651),
       DSPComplex(-0.015037533839,  0.032270195219),
       DSPComplex( 0.047319395233, -0.049920188058),
       DSPComplex(-0.275633692987, -0.077201329969),
       DSPComplex( 0.260550021883, -0.026872750426),
       DSPComplex( 0.154250187563, -0.051859524539),
       DSPComplex( 0.085702710731, -0.034956856551)]

    let firfilt_crcf_data_h13x32_y = [
       DSPComplex(-0.000769529978,  0.000058143975),
       DSPComplex(-0.000855209812, -0.000614414049),
       DSPComplex( 0.017978713542, -0.001770120683),
       DSPComplex( 0.001784905863,  0.017010423559),
       DSPComplex( 0.008329226648, -0.005905805446),
       DSPComplex(-0.000377533572, -0.013277356194),
       DSPComplex( 0.019781654463, -0.010739936790),
       DSPComplex( 0.004673510867, -0.017536447645),
       DSPComplex(-0.018937503016,  0.001766778181),
       DSPComplex(-0.009796095237, -0.022965903194),
       DSPComplex(-0.011542534189,  0.009647205778),
       DSPComplex(-0.026694559597,  0.028680204257),
       DSPComplex(-0.004613286077, -0.018608161470),
       DSPComplex( 0.011559988327,  0.025425767569),
       DSPComplex( 0.015974924004,  0.005946996608),
       DSPComplex(-0.007726490650,  0.012377335870),
       DSPComplex(-0.007714581040, -0.006039979551),
       DSPComplex( 0.018766419009, -0.012572800123),
       DSPComplex(-0.012542031545,  0.012437887461),
       DSPComplex( 0.000458385988,  0.000571447349),
       DSPComplex( 0.016943660061,  0.007409564688),
       DSPComplex( 0.024399758745, -0.020976831445),
       DSPComplex( 0.007946403220,  0.025133322345),
       DSPComplex(-0.012852674380, -0.005689128468),
       DSPComplex( 0.003313037804,  0.000263249514),
       DSPComplex(-0.027377402722, -0.004127607511),
       DSPComplex(-0.026320368186,  0.009134835527),
       DSPComplex(-0.012297987932,  0.013200852928),
       DSPComplex( 0.007101262388, -0.017149417134),
       DSPComplex( 0.000657385901,  0.001192381502),
       DSPComplex(-0.008080139857,  0.018480645475),
       DSPComplex(-0.007551765865,  0.003627711775)]

    let firfilt_crcf_data_h23x64_h: [Float] = [
        0.158654410967,
       -0.020397216842,
       -0.054283334982,
        0.077922310650,
       -0.072938526203,
       -0.018649195029,
        0.037699516688,
        0.039617662775,
       -0.201106990060,
       -0.045133363773,
       -0.083275831491,
       -0.080588772189,
       -0.009860694810,
        0.086105167459,
        0.145475786114,
       -0.015729607185,
       -0.064199255334,
       -0.041339777246,
        0.031333251672,
       -0.178929283974,
       -0.144469434532,
       -0.088642880661,
        0.061210119166]

    let firfilt_crcf_data_h23x64_x = [
       DSPComplex(-0.061754655621,  0.035123551291),
       DSPComplex(-0.042987945529,  0.204710494551),
       DSPComplex(-0.115448103025, -0.048546960311),
       DSPComplex(-0.107929842580, -0.067280385493),
       DSPComplex(-0.138103588190,  0.010448310166),
       DSPComplex(-0.001556297552,  0.087792883061),
       DSPComplex( 0.046355639811,  0.064514990229),
       DSPComplex(-0.073718979418,  0.103212389197),
       DSPComplex(-0.167000830993, -0.051389222147),
       DSPComplex(-0.014426416714,  0.176317900074),
       DSPComplex(-0.107373342455, -0.005804161965),
       DSPComplex( 0.080493073150, -0.061646586042),
       DSPComplex( 0.027796421084, -0.154117176222),
       DSPComplex( 0.146227243025, -0.085442723323),
       DSPComplex(-0.069720789489,  0.186876621048),
       DSPComplex( 0.062823376713,  0.065977046975),
       DSPComplex( 0.090031816754,  0.114581114467),
       DSPComplex( 0.086442323768,  0.125045380084),
       DSPComplex( 0.019615700330, -0.022164049481),
       DSPComplex( 0.002010913947,  0.016348332723),
       DSPComplex( 0.115492888651, -0.140112679132),
       DSPComplex(-0.000370552599,  0.115418598778),
       DSPComplex( 0.171462023973,  0.045787506437),
       DSPComplex(-0.044111687463, -0.011704116119),
       DSPComplex(-0.267816339997,  0.084734013406),
       DSPComplex( 0.013814245144,  0.002740227971),
       DSPComplex( 0.090220778414,  0.134830380675),
       DSPComplex(-0.106145737111, -0.024658098491),
       DSPComplex(-0.112807070004,  0.044997920710),
       DSPComplex(-0.192053613103, -0.062114377970),
       DSPComplex(-0.079637314543,  0.045259089396),
       DSPComplex( 0.012470128523, -0.117498759881),
       DSPComplex(-0.029098880159,  0.100511335166),
       DSPComplex( 0.076820185739, -0.000579442122),
       DSPComplex(-0.146557365265,  0.068919305920),
       DSPComplex( 0.046650052137,  0.086754950098),
       DSPComplex( 0.049312254431,  0.100155311839),
       DSPComplex(-0.018181427657, -0.155695073922),
       DSPComplex(-0.020818721382,  0.050839229113),
       DSPComplex( 0.075624933038, -0.140809485613),
       DSPComplex( 0.024131064286, -0.061085135867),
       DSPComplex(-0.031646019927, -0.020171616314),
       DSPComplex( 0.029466323016, -0.143095954720),
       DSPComplex(-0.000140873686,  0.104732973661),
       DSPComplex( 0.124462359562, -0.105079943629),
       DSPComplex(-0.058374142846,  0.033466529094),
       DSPComplex( 0.026595988216,  0.220281782376),
       DSPComplex(-0.007221829817,  0.141135026450),
       DSPComplex(-0.021218003577, -0.050066565886),
       DSPComplex( 0.035694484054,  0.231602026762),
       DSPComplex( 0.102466686268, -0.099286054817),
       DSPComplex(-0.054792214672,  0.060392934122),
       DSPComplex(-0.001852582407,  0.025794064903),
       DSPComplex( 0.071274514129,  0.142237231718),
       DSPComplex( 0.029476880291,  0.023165981190),
       DSPComplex(-0.027797892310, -0.051616914281),
       DSPComplex( 0.061786844168,  0.001190554171),
       DSPComplex( 0.041304624689, -0.028506531399),
       DSPComplex(-0.075701492591, -0.019189579127),
       DSPComplex(-0.043195431393, -0.100084431779),
       DSPComplex( 0.039964361882,  0.004559897250),
       DSPComplex(-0.252729884604, -0.091698894534),
       DSPComplex(-0.056671384848,  0.100393269844),
       DSPComplex( 0.047875493425, -0.053453060952)]

    let firfilt_crcf_data_h23x64_y = [
       DSPComplex(-0.009797648512,  0.005572506341),
       DSPComplex(-0.005560604075,  0.031761800240),
       DSPComplex(-0.014087267678, -0.013784337240),
       DSPComplex(-0.017247262021, -0.018059567129),
       DSPComplex(-0.012287793463,  0.019054948700),
       DSPComplex( 0.003719976223, -0.002001383647),
       DSPComplex( 0.013367035883,  0.003682443788),
       DSPComplex(-0.017360179024,  0.026029334165),
       DSPComplex(-0.009179615321, -0.007210433367),
       DSPComplex( 0.014210107693, -0.025365792504),
       DSPComplex( 0.004045839585, -0.004700697501),
       DSPComplex( 0.037185762921, -0.032401586998),
       DSPComplex( 0.069046316115, -0.013271584282),
       DSPComplex( 0.033064747039, -0.020579633062),
       DSPComplex(-0.010997016057,  0.045070901497),
       DSPComplex( 0.004422576554,  0.002390243257),
       DSPComplex( 0.033125238067, -0.006016697456),
       DSPComplex(-0.016975087630, -0.035483520861),
       DSPComplex( 0.038314599881, -0.033008052971),
       DSPComplex( 0.036960796853,  0.013280585218),
       DSPComplex( 0.048652304550, -0.021208466846),
       DSPComplex(-0.029006820125,  0.022587827802),
       DSPComplex( 0.028022156827,  0.005836099363),
       DSPComplex( 0.022094506847,  0.031041275846),
       DSPComplex(-0.052928165220, -0.021052052066),
       DSPComplex( 0.018511503181, -0.110568047514),
       DSPComplex( 0.013151749885, -0.084455750067),
       DSPComplex(-0.002103151576, -0.014246866235),
       DSPComplex(-0.004981810769,  0.036099080474),
       DSPComplex( 0.027562144328, -0.004142628424),
       DSPComplex(-0.062965485082, -0.000721660223),
       DSPComplex( 0.001355528130,  0.039494603193),
       DSPComplex(-0.013676340973,  0.019821560124),
       DSPComplex( 0.017190322837, -0.023603201848),
       DSPComplex(-0.013639010839, -0.090413596530),
       DSPComplex( 0.035568646535, -0.005785803158),
       DSPComplex( 0.009541669638, -0.037656127703),
       DSPComplex(-0.037436737172, -0.045380997215),
       DSPComplex(-0.001373976193, -0.005853270514),
       DSPComplex( 0.037863401295,  0.058080181959),
       DSPComplex( 0.036122757372, -0.031465040781),
       DSPComplex(-0.080256218002,  0.010144726857),
       DSPComplex(-0.012130289685, -0.064577476905),
       DSPComplex( 0.001740193468, -0.024376309816),
       DSPComplex( 0.062877940058, -0.049615721082),
       DSPComplex( 0.020116976889, -0.036592663265),
       DSPComplex(-0.000380054511,  0.039223753313),
       DSPComplex( 0.017068821785,  0.021526831643),
       DSPComplex( 0.021954695055,  0.037691348334),
       DSPComplex( 0.067990755649,  0.068783656132),
       DSPComplex( 0.037145711035,  0.043650952232),
       DSPComplex(-0.014003385917, -0.065891325372),
       DSPComplex(-0.048189055475,  0.056129109261),
       DSPComplex( 0.057414520047, -0.036184434048),
       DSPComplex(-0.016064913162, -0.054756587631),
       DSPComplex(-0.016229690128, -0.092689300019),
       DSPComplex( 0.009080345865,  0.006957646952),
       DSPComplex( 0.017213929524, -0.068928651567),
       DSPComplex(-0.036862824002,  0.024446597685),
       DSPComplex(-0.018313177259,  0.012846228600),
       DSPComplex(-0.002556177228,  0.060786016298),
       DSPComplex(-0.069716561264,  0.004791194532),
       DSPComplex(-0.004221111697, -0.015828369005),
       DSPComplex( 0.018252044788,  0.020184229477)]

    let firfilt_crcf_data_h4x8_h: [Float] = [
        0.081125556518,
       -0.048097526791,
        0.083945750272,
        0.016820374297]

    let firfilt_crcf_data_h4x8_x = [
       DSPComplex( 0.212556497097, -0.062593316778),
       DSPComplex( 0.074632428892, -0.155168218555),
       DSPComplex(-0.139928836211, -0.151937330426),
       DSPComplex( 0.057785165005,  0.027214057011),
       DSPComplex( 0.047104310251, -0.016114794312),
       DSPComplex( 0.140236563713,  0.296500956218),
       DSPComplex(-0.134588116658, -0.011633439603),
       DSPComplex( 0.035369414992, -0.047878728319)]

    let firfilt_crcf_data_h4x8_y = [
       DSPComplex( 0.017243764119, -0.005077917658),
       DSPComplex(-0.004168844485, -0.009577524353),
       DSPComplex( 0.002901774665, -0.010117235877),
       DSPComplex( 0.021258439696, -0.004562990201),
       DSPComplex(-0.009449045890, -0.017980731205),
       DSPComplex( 0.011608332082,  0.024557748499),
       DSPComplex(-0.012737392976, -0.016099749821),
       DSPComplex( 0.021907294708,  0.021294289547)]

    let firfilt_crcf_data_h7x16_h: [Float] = [
        0.027835212534,
       -0.040645664069,
       -0.095885554580,
        0.200974194416,
        0.142773900141,
       -0.084839081860,
        0.026675441534]

    let firfilt_crcf_data_h7x16_x = [
       DSPComplex(-0.050554619430, -0.051932459243),
       DSPComplex( 0.033654160787,  0.041969310283),
       DSPComplex( 0.083110727700,  0.078162488859),
       DSPComplex(-0.077891200631, -0.098321707426),
       DSPComplex(-0.187861386260, -0.107086777579),
       DSPComplex(-0.151977015997,  0.027468572824),
       DSPComplex( 0.081513596724,  0.062785557274),
       DSPComplex( 0.031782625481, -0.013462505188),
       DSPComplex(-0.007610286404,  0.087544934055),
       DSPComplex( 0.155881117469,  0.110195135092),
       DSPComplex(-0.104429397916,  0.137400420010),
       DSPComplex(-0.116176549274,  0.071085593565),
       DSPComplex(-0.164136953851,  0.202903767828),
       DSPComplex( 0.084667802512,  0.059492856539),
       DSPComplex( 0.026416620904,  0.138990393077),
       DSPComplex(-0.116423582608, -0.028759261678)]

    let firfilt_crcf_data_h7x16_y = [
       DSPComplex(-0.001407198576, -0.001445551040),
       DSPComplex( 0.002991596797,  0.003279053964),
       DSPComplex( 0.005792966776,  0.005449371658),
       DSPComplex(-0.018933330628, -0.020375106640),
       DSPComplex(-0.010486602589, -0.005458937140),
       DSPComplex( 0.036671134061,  0.040651505702),
       DSPComplex( 0.018467514775, -0.002647275592),
       DSPComplex(-0.042885517171, -0.046631668104),
       DSPComplex(-0.057859564144, -0.002378383977),
       DSPComplex( 0.010144797998,  0.023802283800),
       DSPComplex( 0.017394817258, -0.007977151925),
       DSPComplex(-0.021897278604, -0.003093924849),
       DSPComplex( 0.039886090889,  0.027046322091),
       DSPComplex( 0.022929460881,  0.022153334200),
       DSPComplex(-0.038653803420,  0.008885169596),
       DSPComplex(-0.048989194709,  0.030055784593)]
  
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}