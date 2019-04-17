# YzLog

Swift 代码编写的关于日志打印的需求

外面操作的类是 **YzLog()**

#### 功能 
1. debug 时打印日志，release 时不打印日志
2. 可以在 App 界面最上层显示日志，只有显示功能
3. 在浏览器实时展示APP的日志。启动server，可以在电脑的浏览器输入 `http://ip:8080/` (ip为手机的IP地址)

**以上功能只有通过 `log.info()` 打印的日志才可以，`log` 为 `YzLog()`的实例对象**

#### 应用方式

AppDelegate.swift
```Swift
import UIKit

let log = YzLog()

@UIApplicationMain
```

ViewController.Swift

```Swift
    var count = 0
    override func viewDidLoad() {
        super.viewDidLoad()
        log.info("打印日志开始")
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { (ktimer) in
            self.count += 1
            log.info(self.count)
        }
    }
```

#### YzLog() 的进化过程
最开始的需求只是打印的调试日志不想 release 版本的时候也打印。所以就有了 `info` 函数
```Swift
    public func info<T>(_ message: T,
                        file: String = #file,
                        line: Int = #line,
                        method: String = #function) {
        #if DEBUG
        let str = "\(Date.init().dateFormatString(format: "yyyy-MM-dd HH:mm:ss.SSS")) isMainThread = \(Thread.current.isMainThread) 💙 [\((file as NSString).lastPathComponent)[\(line)] \(method)]: \(message)\n"
        print(str)
        #endif
    }    
```
然后做了一个没有UI的下载功能，QA 没有办法黑盒测试，只能靠打印的日志来查看功能完成情况，所以就有了日志在 App 界面显示的功能

`info` 函数中的关键代码
```Swift
   DispatchQueue.main.async {
            if YzLogDisplayWindow.share.isHidden == false {
                YzLogDisplayWindow.printLog(with: s)
            }
        }  
```
开启关闭方法是
```Swift
    if sender.isOn {
        log.showLogWindow()
    }else{
        log.hiddenLogWindow()
    } 
```

再然后又需要当 App 切后台后也要看到日志，想知道下载的完成情况。所以就又加了浏览器实时展示APP的日志的功能

`info` 函数中的关键代码
```Swift
    httpServerLogger.printLog(with: s)
```
开启关闭方法是
```Swift
    log.httpServer(enable: sender.isOn)
```

最后我是通过宏 ADHOC 和 DEBUG 来控制是否在 “测试包”、“debug包”和“App Store包” 中显示这些功能的