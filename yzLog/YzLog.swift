//
//  YzLog.swift
//  yzLog
//
//  Created by Yz on 2019/4/17.
//  Copyright © 2019 Yz. All rights reserved.
//

import UIKit
//#if ADHOC
import GCDWebServer
//#endif

class YzLog: NSObject {
    public func info<T>(_ message: T,
                        file: String = #file,
                        line: Int = #line,
                        method: String = #function) {
        #if DEBUG
        let str = "\(Date.init().dateFormatString(format: "yyyy-MM-dd HH:mm:ss.SSS")) isMainThread = \(Thread.current.isMainThread) 💙 [\((file as NSString).lastPathComponent)[\(line)] \(method)]: \(message)\n"
        print(str)
        
        //        #endif
        //
        //        #if ADHOC
        
        let s = "\(Date.init().dateFormatString(format: "yyyy-MM-dd HH:mm:ss.SSS")) isMainThread = \(Thread.current.isMainThread) 💙 [\((file as NSString).lastPathComponent)[\(line)] \(method)]: \(message)\n"
        DispatchQueue.main.async {
            if YzLogDisplayWindow.share.isHidden == false {
                YzLogDisplayWindow.printLog(with: s)
            }
        }
        
        httpServerLogger.printLog(with: s)
        #endif
        
    }
    
    //查看代码执行时间，单面毫秒
    public func recordExecuteTime(file: String = #file,
                                  line: Int = #line,
                                  method: String = #function,
                                  block: () ->Void ){
        #if DEBUG
        let startTime = CFAbsoluteTimeGetCurrent()
        block()
        let etime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        info("耗时 = \( etime)",file: file,line: line,method: method)
        #else
        block()
        #endif
    }
    
//    #if ADHOC
    
    func showLogWindow(){
        DispatchQueue.main.async {
            YzLogDisplayWindow.share.isHidden = false
        }
    }
    
    func hiddenLogWindow(){
        DispatchQueue.main.async {
            YzLogDisplayWindow.share.isHidden = true
            YzLogDisplayWindow.share.refreshUI()
        }
    }
    
    /// 启动日志服务
    /// 在浏览器中输入 http://ip:8080/ 就可以浏览日志了
    /// - Parameter enable: 日志服务使能位
    public func httpServer(enable:Bool){
        UserDefaults.standard.set(enable, forKey: "YzLogHttpServerLogger")
        if enable {
            _ = httpServerLogger.startServer()
        }else {
            httpServerLogger.stopServer()
        }
    }
    public func isHttpServerEnable() -> Bool{
        return UserDefaults.standard.bool(forKey: "YzLogHttpServerLogger")
    }
    
    
    private var httpServerLogger: HttpServerLogger = {
        if UserDefaults.standard.bool(forKey: "YzLogHttpServerLogger") {
            return HttpServerLogger().startServer()
        }
        return HttpServerLogger()
    }()
    
    deinit {
        httpServerLogger.stopServer()
    }

//    #endif
}



//#if ADHOC
fileprivate class  YzLogModel {
    var timeBirth:TimeInterval
    var log:String
    init(log:String) {
        self.log = log
        self.timeBirth = Date.timeIntervalSinceReferenceDate
    }
}

fileprivate class YzLogDisplayWindow: UIWindow {
    static let share = YzLogDisplayWindow(frame: CGRect(x:0,y:0,width:UIScreen.main.bounds.size.width, height:UIScreen.main.bounds.size.height))
    
    private var textView = UITextView()
    private var logs = Array<YzLogModel>()
    /// 打印日志
    class func printLog(with log:String) {
        share.printLog(newLog: log)
    }
    
    class func clearLog() {
        DispatchQueue.main.async {
            share.clearLogs()
        }
    }
    
    func refreshUI() {
        DispatchQueue.main.async {
            self.frame = CGRect(x:0,y:0,width:UIScreen.main.bounds.size.width, height:UIScreen.main.bounds.size.height)
             self.textView.frame = self.bounds
        }
    }
    
    private override init(frame: CGRect) {
        super.init(frame: frame)
        self.rootViewController = UIViewController()
        self.windowLevel = UIWindow.Level.alert
        self.backgroundColor = UIColor.init(red: 1.0, green: 0.5, blue: 0.5, alpha: 0.2)
        self.isUserInteractionEnabled = false
        
        self.textView.frame = self.bounds
        self.textView.font = UIFont.systemFont(ofSize: 12.0)
        self.textView.backgroundColor = UIColor.clear
        self.textView.scrollsToTop = false
        self.addSubview(self.textView)
    }
    
    private func printLog(newLog: String) {
        guard newLog.count > 0 else {
            return
        }
        
        synchronized(lock: self) {
            let logStr = newLog +  "\n"
            let logModel = YzLogModel(log: logStr)
            if self.logs.count > 15 {
                self.logs.removeFirst()
            }
            self.logs.append(logModel)
            refreshLogDisplay()
        }
    }
    
    private func synchronized(lock:AnyObject, closure:()->()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    /// 刷新log
    private func refreshLogDisplay() {
        let attributeStr = NSMutableAttributedString.init()
        let currentTimeBirth = Date.timeIntervalSinceReferenceDate
        for log in self.logs {
            let logStr = NSMutableAttributedString.init(string:log.log)
            let logColor = (currentTimeBirth - log.timeBirth) > 0.1 ? UIColor.white : UIColor.blue
            logStr.addAttribute(NSAttributedString.Key.foregroundColor, value: logColor, range: NSMakeRange(0, logStr.length))
            attributeStr.append(logStr)
        }
        
        self.textView.attributedText = attributeStr
        
        if attributeStr.length > 0 {
            let bottomRange = NSMakeRange(attributeStr.length - 1, 1)
            self.textView.scrollRangeToVisible(bottomRange)
        }
        
    }
    
    private func clearLogs() {
        self.textView.attributedText = nil
        self.logs.removeAll()
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

fileprivate class HttpServerLogger: NSObject {
    
    
    private var logs = Array<YzLogModel>()
    
    var  webServer:GCDWebServer?
    
    @discardableResult
    func startServer() -> HttpServerLogger  {
        DispatchQueue.main.async {
            if self.webServer == nil {
                self.webServer = GCDWebServer()
                self.webServer?.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self, processBlock: {[weak self](request) -> GCDWebServerResponse? in
                    return self?.createResponseBody(request)
                } )
                
                self.webServer?.start(withPort: 8080, bonjourName: "GCD Web Server")
            }
        }
        
        return self
    }
    func stopServer()  {
        DispatchQueue.main.async {
            self.webServer?.stop()
            self.webServer = nil
        }
    }
    
    func printLog(with newLog: String) {
        guard newLog.count > 0 else {
            return
        }
        synchronized(lock: self) {
            let logModel = YzLogModel(log: newLog)
            if self.logs.count > 100 {
                self.logs.removeFirst()
            }
            self.logs.append(logModel)
        }
    }
    
    private func synchronized(lock:AnyObject, closure:()->()) {
        objc_sync_enter(lock)
        closure()
        objc_sync_exit(lock)
    }
    
    
    func createResponseBody(_ request: GCDWebServerRequest) -> GCDWebServerResponse?  {
        //        var response:GCDWebServerResponse
        var s = ""
        let path = request.path;
        let query = request.query;
        if path == "/" {
            s.append("<!DOCTYPE html><html lang=\"en\">")
            s.append("<head><meta charset=\"utf-8\"></head>")
            s.append("<title>\(String(describing: getprogname()))[\(getpid())]</title>")
            s.append("""
                <style>\
                body {\n\
                margin: 0px;\n\
                font-family: Courier, monospace;\n\
                font-size: 0.8em;\n\
                }\n\
                table {\n\
                width: 100%;\n\
                border-collapse: collapse;\n\
                }\n\
                tr {\n\
                vertical-align: top;\n\
                }\n\
                tr:nth-child(odd) {\n\
                background-color: #eeeeee;\n\
                }\n\
                td {\n\
                padding: 2px 10px;\n\
                }\n\
                #footer {\n\
                text-align: center;\n\
                margin: 20px 0px;\n\
                color: darkgray;\n\
                }\n\
                .error {\n\
                color: red;\n\
                font-weight: bold;\n\
                }\n\
                </style>
            """)
            s.append("""
            <script type=\"text/javascript\">\n\
            var refreshDelay=500;var footerElement=null;function getScrollTop(){var scrollTop=0,bodyScrollTop=0,documentScrollTop=0;if(document.body){bodyScrollTop=document.body.scrollTop}if(document.documentElement){documentScrollTop=document.documentElement.scrollTop}scrollTop=(bodyScrollTop-documentScrollTop>0)?bodyScrollTop:documentScrollTop;return scrollTop}function getScrollHeight(){var scrollHeight=0,bodyScrollHeight=0,documentScrollHeight=0;if(document.body){bodyScrollHeight=document.body.scrollHeight}if(document.documentElement){documentScrollHeight=document.documentElement.scrollHeight}scrollHeight=(bodyScrollHeight-documentScrollHeight>0)?bodyScrollHeight:documentScrollHeight;return scrollHeight}function getWindowHeight(){var windowHeight=0;if(document.compatMode=="CSS1Compat"){windowHeight=document.documentElement.clientHeight}else{windowHeight=document.body.clientHeight}return windowHeight}function updateTimestamp(){var now=new Date();footerElement.innerHTML="Last updated on "+now.toLocaleDateString()+" "+now.toLocaleTimeString()}function refresh(){var timeElement=document.getElementById("maxTime");var maxTime=timeElement.getAttribute("data-value");timeElement.parentNode.removeChild(timeElement);var xmlhttp=new XMLHttpRequest();xmlhttp.onreadystatechange=function(){if(xmlhttp.readyState==4){if(xmlhttp.status==200){var b=(getScrollTop()+getWindowHeight()==getScrollHeight());var contentElement=document.getElementById("content");contentElement.innerHTML=contentElement.innerHTML+xmlhttp.responseText;updateTimestamp();if(b){window.scrollTo(0,document.body.scrollHeight)}setTimeout(refresh,refreshDelay)}else{footerElement.innerHTML='<span class="error">Connection failed! Reload page to try again.</span>'}}};xmlhttp.open("GET","/log?after="+maxTime,true);xmlhttp.send()}window.onload=function(){footerElement=document.getElementById("footer");updateTimestamp();setTimeout(refresh,refreshDelay)};
            </script>
            """)
            s.append("</head><body><table><tbody id=\"content\">")
            s.append(_appendLogRecords(afterAbsoluteTime:0))
            
            s.append("</tbody></table><div id=\"footer\"></div></body></html>")
            
            
        } else if path == "/log" , let timeStr = query?["after"]{
            
            s = self._appendLogRecords(afterAbsoluteTime: Double(timeStr)!)
            
        } else {
            s = "<html><body><p>无数据</p></body></html>"
        }
        
        return GCDWebServerDataResponse(html: s)
        //        return response
    }
    
    func _appendLogRecords(afterAbsoluteTime:Double) -> String{
        var time = afterAbsoluteTime as TimeInterval
        var s:String = String()
        synchronized(lock: self){
            for log in self.logs {
                let style = "color: dimgray;";
                if log.timeBirth > afterAbsoluteTime as TimeInterval {
                    s.append("<tr style=\"\(style)\"><td>\(log.log)\n</td></tr>")
                    s.append("<tr><td>\r\n<td></tr><tr></tr>")
                    time = log.timeBirth
                }
            }
        }
        s.append("<tr id=\"maxTime\" data-value=\"\(time)\"></tr>")
        return s
    }
}


//#endif

public extension Date {
    func dateFormatString(format: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = format
        return dateFormatter.string(from: self)
    }
}
