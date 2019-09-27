//
//  ViewController.swift
//  AirConAvgCubicWeightCalculator
//
//  Created by Vinnie Liu on 27/9/19.
//  Copyright © 2019 Yawei Liu. All rights reserved.
//

import UIKit
import SwiftyJSON
import SVProgressHUD
import Alamofire
import LTMorphingLabel

//this model class is used to store every Air Conditioner Object values that we fetched
//remotely, it's constructed with all the sensitive data that we need, for those redundant
//attributes like title and weight, we will ignore them to save some data transport cost
class AirConObject{
    var width: Double = 0.0
    var length: Double = 0.0
    var height: Double = 0.0
    var cubicWeight: Double = 0.0
    var dataMissing: Bool = false
    
    //this is the default constructor for the class
    //we assume that there is no data missing in this case
    //coz even if e.g. the width data is missing, we will still pass a 0.0 here to
    //construct a AirConObject object
    init(_ width: Double, _ length: Double, _ height: Double) {
        self.width = width
        self.length = length
        self.height = height
    }
    
    //this method is used to calculate the cubic weight for this particular AirConObject
    //we will store the result as a variable for this object, this method will be executed
    //immediately when a new AirConObject is constructed, so in the future we can directly
    //get the cubicWeight of this AirConObject for other calculation purpose
    func calculateCubicWeight(){
        self.cubicWeight = Double(round(250000 * self.width * self.length * self.height)/1000)
    }
}

//this is the default and home VC class for this project
class ViewController: UIViewController {
    
    
    @IBOutlet weak var resultLabel: LTMorphingLabel!
    @IBOutlet weak var tyLabel: LTMorphingLabel!
    @IBOutlet weak var footerlabel: LTMorphingLabel!
    
    
    //here we created a global variable AirConObject custom class array to store every
    //single Air Conditioner product that we fetched from the API
    var airConProductsArray = [AirConObject]()
    
    //this is the header for the API, we need to make multiple API calls to get the complete data
    //we will store this string as a constant variable, and we will combine it with the different sub directory
    //roots to get a new full URL for the new API call
    let queryUrlHeader = "http://wp8m3he1wt.s3-website-ap-southeast-2.amazonaws.com"
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.drawBgImage()
        self.fetchDataFromAPI("http://wp8m3he1wt.s3-website-ap-southeast-2.amazonaws.com/api/products/1")
    }
    
    //this method is used to display a more user-friendly background image
    //rather than the dull blank white background
    func drawBgImage(){
        UIGraphicsBeginImageContext(self.view.frame.size)
        UIImage(named: "bg_image")?.draw(in: self.view.bounds)
        let image: UIImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        let backgroundColor = UIColor(patternImage: image)
        self.view.backgroundColor = backgroundColor
    }
    
    //In this method, we will make a GET request to the API address to fetch the data
    //we noticed that, the complete datasource stores in several different places, the next object tells us if there is anymore,that's why we will use a recurring logic to make the call based on the most recent data fetch, if the next object is not null, we will combine the full query url and make a new call
    //in the mean time, we should take care of the data input volume, here we making it sequentially requests instead of parallel requests for efficiency, to elaborate, the new request will be made only when the previous one is completed
    func fetchDataFromAPI(_ queryUrl: String){
        
        //This is a loading Spinner animation to give the user a prompt that we are doing
        //some data transmission, it's always important to give the user hints to tell them
        //that the app is working, not dead, it's a basic UX requirement
        SVProgressHUD.show(withStatus: "Contacting Server...")
        
        let headers = [
            "Content-Type": "application/json;charset=UTF-8"
        ]
        
        //here we will use Alamofire, a popular HTTP networking library for iOS to make the API calls
        Alamofire.request(queryUrl, method: .get, parameters: nil, encoding: JSONEncoding.default, headers: headers).responseJSON { (responseData) -> Void in
            switch responseData.result{
            //we will check if we did successfully received some data before we dive into the data fetching part
            case .success(_):
                
                if let resValue = responseData.result.value{
                    let productJsonValue = JSON(resValue)
                    
                    //here we use a library called SwiftyJSON, coz in iOS environment,
                    //dealing with JSON is tedious and troublesome process, it's very easy to
                    //cause the App Client crash, but with this library, we can always avoid crash
                    //even if the server passes some null objects to us
                    let objectsArray = productJsonValue["objects"].arrayValue
                    if objectsArray.isEmpty == false{
                        for singleObject in objectsArray{
                            if let category = singleObject["category"].string {
                                if category == "Air Conditioners"{
                                    let sizeJSON = singleObject["size"]
                                    //here with the SwiftyJSON library, we can deal with data missing properly
                                    //coz if the width data is missing, we will still pass a 0.0, so we can check
                                    //the value if it's zero to find out if there is any data value missing for more accurate
                                    //average data calculation
                                    let airConWidthInMetre =  Double(round(1000 * sizeJSON["width"].doubleValue)/100000)
                                    let airConLengthInMetre = Double(round(1000 * sizeJSON["length"].doubleValue)/100000)
                                    let airConHeightInMetre = Double(round(1000 * sizeJSON["height"].doubleValue)/100000)
                                    let newAirConObj = AirConObject(airConWidthInMetre, airConLengthInMetre, airConHeightInMetre)
                                    //we will check if one of the three attributes is missing, we will mark this product as
                                    //data missing product, so for future average calculation, we can take care of it for
                                    //more accurate average value calculation
                                    if airConLengthInMetre == 0.0 || airConWidthInMetre == 0.0 || airConHeightInMetre == 0.0{
                                        newAirConObj.dataMissing = true
                                    }
                                    //here we will calculate the cubic weight of the AirCon object and update its
                                    //variable for future access
                                    newAirConObj.calculateCubicWeight()
                                    //everything is done with this single product, we can now append it into the custom object class array
                                    self.airConProductsArray.append(newAirConObj)
                                }
                            }
                        }
                    }
                    //here we will check if this request gives us some hint,
                    let nextQueryUrlRoot = productJsonValue["next"].stringValue
                    //if the "next" attribute gives us a null value, we assume that this is the complete datasouce, there is no more data, we can now wrap it up and do the final calculation
                    if nextQueryUrlRoot.isEmpty{
                        SVProgressHUD.dismiss(completion: {
                            //here we will sum up all the Air Conditioner Object cubic weight and divide by the
                            //array count number to get the average cubic weight for all the Air Conditioner Products
                            var airConTotalCubicWeight: Double = 0.0
                            let allProductsQuantity = self.airConProductsArray.count
                            //we will check if there is any data missing for the product before calculation
                            //we don't want the missing data to ruin the data persistency, we want the average data
                            //to be more accurate, so we will ignore those products with 0 width or 0 length or 0 height
                            var dataMissingProductCount = 0
                            for product in self.airConProductsArray{
                                if product.dataMissing == false{
                                    airConTotalCubicWeight += product.cubicWeight
                                }else{
                                    dataMissingProductCount += 1
                                }
                            }
                            let validProductsQuantity = allProductsQuantity - dataMissingProductCount
                            //we should take care of the data calculation regulation in Swift, a Double value should only
                            //be divided by a Double value, so we divide it by a double value of the Air Conditioner products quantity
                            let airConAvgCubicWeight = airConTotalCubicWeight / Double(validProductsQuantity)
                            SVProgressHUD.showSuccess(withStatus: "We've fetched \(allProductsQuantity) air con products, \(dataMissingProductCount) products have data missing, \(validProductsQuantity) products value are valid to use, the average cubic weight is \(airConAvgCubicWeight) kg")
                            
                            DispatchQueue.main.async {
                                self.updateResultLabelUI(airConAvgCubicWeight)
                            }
                        })
                    }else{
                        //if the "next" attribute gives us a child path, we shall append it to the queryHeader and use the new combined URL to make a new call
                        let newQueryUrl = self.queryUrlHeader + nextQueryUrlRoot
                        self.fetchDataFromAPI(newQueryUrl)
                    }
                }
            case .failure(let error):
                //if one of the API calls failed, we will stop there and use the fetched data for calculation
                //coz we can't get the next API call route
                //we will print the error description for programmer to debug, but we won't show the
                //complex error message to the actual user
                print(error)
                SVProgressHUD.dismiss(completion: {
                    
                    //here we will sum up all the Air Conditioner Object cubic weight and divide by the
                    //array count number to get the average cubic weight for all the Air Conditioner Products
                    var airConTotalCubicWeight: Double = 0.0
                    let allProductsQuantity = self.airConProductsArray.count
                    //we will check if there is any data missing for the product before calculation
                    //we don't want the missing data to ruin the data persistency, we want the average data
                    //to be more accurate, so we will ignore those products with 0 width or 0 length or 0 height
                    var dataMissingProductCount = 0
                    for product in self.airConProductsArray{
                        if product.dataMissing == false{
                            airConTotalCubicWeight += product.cubicWeight
                        }else{
                            dataMissingProductCount += 1
                        }
                    }
                    let validProductsQuantity = allProductsQuantity - dataMissingProductCount
                    //we should take care of the data calculation regulation in Swift, a Double value should only
                    //be divided by a Double value, so we divide it by a double value of the Air Conditioner products quantity
                    let airConAvgCubicWeight = airConTotalCubicWeight / Double(validProductsQuantity)
                    SVProgressHUD.showError(withStatus: "Data fetching error occured, we've fetched \(allProductsQuantity) air con products, \(dataMissingProductCount) products have data missing, \(validProductsQuantity) products value are valid to use, the average cubic weight is \(airConAvgCubicWeight) kg")
                    DispatchQueue.main.async {
                        self.updateResultLabelUI(airConAvgCubicWeight)
                    }
                })
            }
        }
    }
    
    //this method is used to update the result label to make it looks more
    //eye-catchy and user friendly
    func updateResultLabelUI(_ avgCubicWeight: Double){
        self.resultLabel.text = "Air Con Avg Cubic Weight is: \(avgCubicWeight) kg"
        self.resultLabel.morphingEffect = .sparkle
        self.resultLabel.start()
        self.tyLabel.text = "Thank you for reviewing"
        self.resultLabel.start()
        self.footerlabel.text = "Designed by Yawei Liu(Vinnie)"
        self.footerlabel.start()
    }
}

