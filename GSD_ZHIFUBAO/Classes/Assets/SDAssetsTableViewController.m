//
//  SDAssetsTableViewController.m
//  GSD_ZHIFUBAO
//
//  Created by aier on 15-6-4.
//  Copyright (c) 2015年 GSD. All rights reserved.
//

/*
 
 *********************************************************************************
 *
 * 在您使用此自动布局库的过程中如果出现bug请及时以以下任意一种方式联系我们，我们会及时修复bug并
 * 帮您解决问题。
 * 新浪微博:GSD_iOS
 * Email : gsdios@126.com
 * GitHub: https://github.com/gsdios
 *
 *********************************************************************************
 
 */

#import "SDAssetsTableViewController.h"
#import "SDAssetsTableViewControllerCell.h"
#import "SDAssetsTableViewControllerCellModel.h"
#import "SDAssetsTableViewHeader.h"
#import "LogoutCell.h"
#import "SDYuEBaoTableViewController.h"
#import "LogginController.h"
#import "ProfileManager.h"
#import "iFlyNvpViewController.h"
#import "TrainViewController.h"
#import "Reachability.h"
#import "VoiceModelController.h"

@interface SDAssetsTableViewController () {
    IFlyISVRecognizer* isvRec;
    
    int ivppwdt;
    
    NSArray * numCodeArray;             //数字密码数组  +++++++++++++++++++++++++++++++++++++++++++++++++++++!
    NSString* voiceID;
}

@end

#define IOS7_OR_LATER   ( [[[UIDevice currentDevice] systemVersion] compare:@"7.0"] != NSOrderedAscending )
#define Margin  5
#define Slide   2

#define PWDT_FIXED_CODE  1     //固定密码
#define PWDT_FREE_CODE   2     //自由说
#define PWDT_NUM_CODE    3     //数字密码



#pragma  mark actionsheet tag

#define SETTING_TAG            1
#define FIXED_CODE_VERIFY_TAG  3
#define FIXED_CODE_TRAIN_TAG   2
#define FIXED_CODE_QUERY_TAG   4
#define FIXED_CODE_DEL_TAG     5
//


#pragma  key of isv
#define  KEY_PTXT           @"ptxt"
#define  KEY_RGN            @"rgn"
#define  KEY_TSD            @"tsd"
#define  KEY_SUB            @"sub"
#define  KEY_PWDT           @"pwdt"
#define  KEY_TAIL           @"vad_speech_tail"
#define  KEY_voiceID        @"auth_id"
#define  KEY_SST            @"sst"
#define  KEY_KEYTIMEOUT     @"key_speech_timeout"
#define  KEY_VADTIMEOUT     @"vad_timeout"

#pragma mark value of key
#define  TRAIN_SST          @"train"
#define  VERIFY_SST         @"verify"


#pragma mark del or query
#define  DEL                @"del"
#define  QUERY              @"que"

#pragma mark error code
#define kErrModelNotExist   10116

@implementation SDAssetsTableViewController

-(void)viewWillAppear:(BOOL)animated{
    
    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:animated];

    if ([[ProfileManager sharedInstance] checkLogin]) {
        if (![[ProfileManager sharedInstance] checkVoicePrintExist]) {
            
            //已登录 未录入声纹模型
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"" message:@"请录入声纹模型" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"录入" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
                
//                iFlyNvpViewController * nvp = [[iFlyNvpViewController alloc] init];
//                [self.navigationController pushViewController:nvp animated:YES];
                
                if( [self netConnectAble] == NO ){
                    [self toast:@"无网络连接"];
                    return;
                }
               
                [self trainOrVerifyNumCode:TRAIN_SST];
            }];
            [alert addAction:defaultAction];
            [self presentViewController:alert animated:YES completion:nil];
        }
        
    }else{
        
        //未登录
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"" message:@"请登录" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"登录" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
            
            LogginController* loginController = [[LogginController alloc] init];
            loginController.hidesBottomBarWhenPushed = NO;
            loginController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(dismissLoginView)];
            
            UINavigationController* navController = [[UINavigationController alloc] initWithRootViewController:loginController];
            navController.hidesBottomBarWhenPushed = NO;
            
            loginController.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"返回" style:UIBarButtonItemStylePlain target:self action:@selector(dismissLoginView)];
            
            [self presentViewController:navController animated:YES completion:nil];
            
        }];
        [alert addAction:defaultAction];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.sectionsNumber = 2;
    ivppwdt = PWDT_NUM_CODE;
    
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(recvNotif:) name:@"VoiceModelController" object:nil];
    
    self.cellClass = [SDAssetsTableViewControllerCell class];
    
    //generate voice id
    if (![[ProfileManager sharedInstance] getVoiceID]) {
        //no voice id generated
        voiceID = [[NSString alloc] initWithString:[[[ProfileManager sharedInstance] getUserPhone] stringByAppendingString:kModelSugar]];
        [[ProfileManager sharedInstance] setVoiceID:voiceID];
    }else{
        voiceID = [[NSString alloc] initWithString:[[ProfileManager sharedInstance] getVoiceID]];
    }
    
    isvRec = [IFlyISVRecognizer sharedInstance];
    [isvRec setParameter:TRAIN_SST forKey:KEY_SST];

    [self setupModel];
    [self setUpHeader];
    [self setUpFooter];
    
    //check wheather voice model exists.
//    int err;
//    BOOL ret;
//    ret=[isvRec sendRequest:QUERY authid:voiceID pwdt:PWDT_NUM_CODE ptxt:nil vid:nil err:&err];  // attention isv +++++++++++++++++++++
//    [self processRequestResult:QUERY ret:ret err:err];
    
    NSLog(@"view loaded");
}

- (void)setUpHeader{
    SDAssetsTableViewHeader *header = [[SDAssetsTableViewHeader alloc] init];
    header.iconView.image = [UIImage imageNamed:@"tmall_icon"];
    self.tableView.tableHeaderView = header;
}

- (void)setUpFooter{
    LogoutCell* footer = [[LogoutCell alloc] init];
    footer.delegate = self;
    self.tableView.tableFooterView = footer;
}

- (void)setupModel
{
    // section 0 的model
    SDAssetsTableViewControllerCellModel *model01 = [SDAssetsTableViewControllerCellModel modelWithTitle:@"声纹" iconImageName:@"20000032Icon" destinationControllerClass:[VoiceModelController class]];

    SDAssetsTableViewControllerCellModel *model02 = [SDAssetsTableViewControllerCellModel modelWithTitle:@"指纹" iconImageName:@"20000059Icon" destinationControllerClass:[SDYuEBaoTableViewController class]];
    
    // section 1 的model
    SDAssetsTableViewControllerCellModel *model11 = [SDAssetsTableViewControllerCellModel modelWithTitle:@"个人设置" iconImageName:@"20000118Icon" destinationControllerClass:[SDBasicTableViewController class]];
    
    SDAssetsTableViewControllerCellModel *model12 = [SDAssetsTableViewControllerCellModel modelWithTitle:@"安全设置" iconImageName:@"20000180Icon" destinationControllerClass:[SDBasicTableViewController class]];
    
    self.dataArray = @[@[model01, model02],
                       @[model11, model12]];
}

//训练或者验证 数字密码
-(void)trainOrVerifyNumCode:(NSString *)sst
{
    if( ![sst isEqualToString:VERIFY_SST] && ![sst isEqualToString:TRAIN_SST] ){
        NSLog(@"in %s,sst 参数错误",__func__);
        return;
    }
    
    numCodeArray=[self downloadPassworld:ivppwdt];
    
    if( numCodeArray == nil ){
        [self toast:@"获取密码失败"];
        return;
    }
    
    if( [sst isEqualToString:VERIFY_SST] ){
        if( numCodeArray!=nil && numCodeArray.count > 0 ){
            NSString *ptString=[numCodeArray objectAtIndex:0];
            [self defaultSetparam:voiceID withpdwt: PWDT_NUM_CODE withptxt:ptString trainorverify:VERIFY_SST];
            TrainViewController *trainController=[[TrainViewController alloc]init];
            trainController.numCodeArray =numCodeArray;
            trainController.pwdt=PWDT_NUM_CODE;
            trainController.sst=VERIFY_SST;
            [self presentViewController:trainController animated:YES completion:nil];
        }
        
    }else{
        if( numCodeArray!=nil && numCodeArray.count > 0 ){
            NSString *ptString=[self numArrayToString:numCodeArray];
            [self defaultSetparam:voiceID withpdwt: PWDT_NUM_CODE withptxt:ptString trainorverify:TRAIN_SST];
            TrainViewController *trainController=[[TrainViewController alloc]init];
            trainController.numCodeArray =numCodeArray;
            trainController.pwdt=PWDT_NUM_CODE;
            trainController.sst=TRAIN_SST;
            [self presentViewController:trainController animated:YES completion:nil];
        }
    }
}

//查询模型
- (void)queryButtonHandler:(id)sender
{
    if( [self netConnectAble] == NO )
    {
        [self toast:@"无网络连接"];
        return;
    }//判断网络连接状态
    
    [self startRequestNumCode:QUERY];
}

//数字密码查询或者删除
-(void)startRequestNumCode:(NSString *)queryMode
{
    if( ![queryMode isEqualToString: QUERY] && ![queryMode isEqualToString:DEL] ){
        NSLog(@"in %s,queryMode 参数错误",__func__);
        [self toast:@"para error"];
        return;
    }
    int err;
    BOOL ret;
    ret=[isvRec sendRequest:queryMode authid:voiceID pwdt:PWDT_NUM_CODE ptxt:nil vid:nil err:&err];  // attention isv +++++++++++++++++++++
    [self processRequestResult:queryMode ret:ret err:err];
}

//查询或者时删除返回的结果处理
-(void)processRequestResult:(NSString*)requestMode ret:(BOOL)ret err:(int)err
{
    if( ![requestMode isEqualToString:DEL] && ![requestMode isEqualToString:QUERY]){
        NSLog(@"在%s中，queryMode参数错误",__func__);
        return;
    }
    
    if( [requestMode isEqualToString:QUERY] ){
        if( err != 0 ){
            NSLog(@"查询错误，错误码：%d",err);
            //处理返回值
            if (err == kErrModelNotExist) {
                NSLog(@"模型不存在");
                [[ProfileManager sharedInstance] setVoiceID:@""];
            }
        }else{
            if( ret == NO ){
                NSLog(@"模型不存在");
//                [resultShow setText:@"模型不存在"];
            }else{
                NSLog(@"查询成功");
//                [resultShow setText:@"模型存在！"];
            }
        }
    }else if(  [requestMode isEqualToString:DEL]){
        if( err != 0 ){
            NSLog(@"删除错误，错误码：%d",err);
            //处理返回值
            if (err == kErrModelNotExist) {
                NSLog(@"模型不存在");
                [[ProfileManager sharedInstance] setVoiceID:@""];
            }
        }else{
            if( ret == NO ){
                NSLog(@"模型不存在");
                [self toast:@"模型不存在"];
            }else{
                NSLog(@"删除成功");
                [self toast:@"删除成功"];
            }
        }
    }
}

//删除模型
-(void)deleteButtonHandler:(id)sender
{
    if( [self netConnectAble] == NO )
    {
        [self toast:@"not internet connection"];
        return;
    }

    [self startRequestNumCode:DEL];
}

#pragma mark train or verify model
//声纹默认参数设置
- (void)defaultSetparam:(NSString *)auth_id withpdwt:(int) pwdt withptxt:(NSString *) ptxt trainorverify:(NSString*)sst
{
    if( isvRec != nil ){
        [isvRec setParameter:@"ivp" forKey:KEY_SUB];
        [isvRec setParameter:[NSString stringWithFormat:@"%d",pwdt] forKey:KEY_PWDT];
        [isvRec setParameter:@"50" forKey:KEY_TSD];
        [isvRec setParameter:@"3000" forKey:KEY_VADTIMEOUT];
        [isvRec setParameter:@"700" forKey:KEY_TAIL];
        [isvRec setParameter:ptxt forKey:KEY_PTXT];
        [isvRec setParameter:auth_id forKey:KEY_voiceID];
        [isvRec setParameter:sst forKey:KEY_SST];            /* train or test */
        [isvRec setParameter:@"180000" forKey:KEY_KEYTIMEOUT];
        if( pwdt == PWDT_FIXED_CODE || pwdt == PWDT_NUM_CODE ){
            [isvRec setParameter:@"5" forKey:KEY_RGN];
        }else{
            [isvRec setParameter:@"1" forKey:KEY_RGN];
        }
    }else{
        NSLog(@"isvRec is nil\n");
    }
    
}

#pragma  mark - net detect
//网络连接判断
-(BOOL)netConnectAble
{
    if ( [[Reachability reachabilityForInternetConnection] currentReachabilityStatus] == NotReachable ){
        return NO;
    }
    return YES;
}

#pragma mark - other function
//下载密码
-(NSArray*)downloadPassworld:(int)pwdtParam
{
    
    if( pwdtParam != PWDT_FIXED_CODE && pwdtParam != PWDT_NUM_CODE ){
        NSLog(@"in %s,pwdtParam 参数错误",__func__);
        return nil;
    }
    NSArray* tmpArray=[isvRec getPasswordList:pwdtParam];  // attention isv +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    
    if( tmpArray == nil ){
        NSLog(@"in %s,请求数据有误",__func__);
        return nil;
    }
    
    return tmpArray;   //返回下载
    
}



//数字密码 把array里面的数字 串起来,ISV 固定规则
-(NSString*)numArrayToString:(NSArray *)numArrayParam
{
    if( numArrayParam == nil ){
        NSLog(@"在%s中，numArrayParam is nil",__func__);
        return nil;
    }
    
    NSMutableString *ptxtString = [NSMutableString stringWithCapacity:1];
    [ptxtString appendString:[numArrayParam objectAtIndex:0]];
    
    for (int i = 1;i < [numArrayParam count] ; i++ ){
        NSString *str = [numArrayParam objectAtIndex:i];
        [ptxtString appendString:[NSString stringWithFormat:@"-%@",str]];
        
    }
    return  ptxtString;
}



//根据从网络上获得的密码，生成一个actionsheet并显示所有可用的固定密码
-(BOOL)generateActionSheetWithArray:(NSArray *)arrayParam withTag:(int)tag
{
    if( arrayParam ==nil || arrayParam.count == 0 ){
        NSLog(@"在%s中，文本密码为空，无法生成actionsheet",__func__);
    }
    
    UIActionSheet *showSheet=[[UIActionSheet alloc] initWithTitle:@"选择一个文本密码"
                                                         delegate:self
                                                cancelButtonTitle:nil
                                           destructiveButtonTitle:nil
                                                otherButtonTitles:nil,nil];
    showSheet.tag=tag;
    
    for(int i =0; i< arrayParam.count; i++){
        [showSheet addButtonWithTitle:[arrayParam objectAtIndex:i]];
    }
    
    [showSheet addButtonWithTitle:@"取消"];
    [showSheet showInView:self.view];
    return YES;
    
}

#pragma mark - delegate 

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SDAssetsTableViewControllerCellModel *model = [self.dataArray[indexPath.section] objectAtIndex:indexPath.row];
    UIViewController *vc = [[model.destinationControllerClass alloc] init];
    vc.title = model.title;
    [self.navigationController pushViewController:vc animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return (section == self.dataArray.count - 1) ? 10 : 0;
}

- (void)dismissLoginView {
    NSLog(@"dissmiss");
}

- (void)reloadView {
    [self viewWillAppear:YES];
}

- (void)deleteVoiceModel {
    if( [self netConnectAble] == NO )
    {
        [self toast:@"not internet connection"];
        return;
    }
    
    [self startRequestNumCode:DEL];
}

- (void)recvNotif:(NSNotification*)notify {
    static int index;
    NSLog(@"recv bcast %d", index++);
    
    // 取得广播内容
    NSDictionary *dict = [notify userInfo];
    NSString *name = [dict objectForKey:@"NotifyName"];
    
    if ([name  isEqual: @"deleteModel"]) {
        if( [self netConnectAble] == NO )
        {
            [self toast:@"not internet connection"];
            return;
        }
        
        [self startRequestNumCode:DEL];
 
    }
}

@end
