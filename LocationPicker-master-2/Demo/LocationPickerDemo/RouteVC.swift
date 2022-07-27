//
//  RouteVC.swift
//  LocationPickerDemo
//
//  Created by prashant khatri on 16/07/22.
//  Copyright © 2022 almassapargali. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase

enum FirebasePaths : String {
    case location
    case Admin
    case EventID
    case Host
    case Source
    case Destination
    case Hunter
}

class RouteVC: UIViewController , MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    var sourceLocation: Location?
    @IBOutlet weak var saveRouteButton: UIBarButtonItem!
    var destinationLocation: Location?
    var adminReference:DatabaseReference!
    var hunterReference:DatabaseReference!
    
    var locationDataArray: [CLLocation] = [CLLocation]()
    var userAnnotationImage: UIImage?
    var userAnnotation: UserAnnotation?
    var accuracyRangeCircle: MKCircle?
    var polyline: MKPolyline?
    var isZooming: Bool?
    var isBlockingAutoZoom: Bool?
    var zoomBlockingTimer: Timer?
    var didInitialZoom: Bool?
    var marker:MKPointAnnotation!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.mapView.delegate = self
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        adminReference = Database.database().reference().child(FirebasePaths.location.rawValue).child(FirebasePaths.Admin.rawValue)
        hunterReference = Database.database().reference().child(FirebasePaths.location.rawValue).child(FirebasePaths.Hunter.rawValue)
        addHunterUpdateObserver()
        self.userAnnotationImage = UIImage(named: "user_position_ball")!
        self.didInitialZoom = false

        guard let sourceCoordinate = sourceLocation?.location.coordinate , let destCoordinate = destinationLocation?.location.coordinate  else {
            return
            }
        showRouteOnMap(pickupCoordinate: sourceCoordinate, destinationCoordinate: destCoordinate)
    
        // Do any additional setup after loading the view.
    }
    
    
    
    func updateLocationOnFirebase(source:CLLocationCoordinate2D , destination : CLLocationCoordinate2D){
        let sourcelat = source.latitude
        let sourcelong = source.longitude
        let destinationlat = destination.latitude
        let destinationlong = destination.longitude
        
        let aurthorDict = [FirebasePaths.Source.rawValue : ["lat":sourcelat,"long":sourcelong], FirebasePaths.Destination.rawValue : ["lat":destinationlat,"long":destinationlong]]
        
        adminReference.setValue(aurthorDict) { (error, reference) in
            if error == nil {
                self.navigationController?.popViewController(animated: true)
                print("location successfully updated")
            }
        }
    }
    
    @IBAction func SaveRouteAction(_ sender: Any) {
        guard let sourceCoordinate = sourceLocation?.location.coordinate , let destCoordinate = destinationLocation?.location.coordinate  else {
            return
            }
        self.updateLocationOnFirebase(source: sourceCoordinate, destination: destCoordinate)
    }
    
    func addHunterUpdateObserver(){
        hunterReference.observe(.value) {[weak self] (snapShot) in
            guard let self = self else{return}
            if let value = snapShot.value as? NSDictionary{
                guard let lat = value["lat"] as? CLLocationDegrees ,let long = value["long"] as? CLLocationDegrees else{return}
                
                 let location = CLLocation(latitude: lat , longitude: long )
                self.locationDataArray.append(location)
                self.updatePolylines()
                self.zoomTo(location: location)
                print("location latitude is \(lat) and longitute is \(long)")
            }
        }
        
    }
    
    
    
    func updatePolylines(){
        var coordinateArray = [CLLocationCoordinate2D]()
        for loc in self.locationDataArray{
            coordinateArray.append(loc.coordinate)
        }
        self.clearPolyline()
        self.polyline = MKPolyline(coordinates: coordinateArray, count: coordinateArray.count)
        self.mapView.addOverlay(polyline!)
        
    }
    
    func clearPolyline(){
        if self.polyline != nil{
            self.mapView.removeOverlay(self.polyline!)
            self.polyline = nil
        }
    }
    
    func zoomTo(location: CLLocation){
        if self.didInitialZoom == false{
            let coordinate = location.coordinate
            let region = MKCoordinateRegion.init(center: coordinate, latitudinalMeters: 300, longitudinalMeters: 300)
            self.mapView.setRegion(region, animated: false)
            self.didInitialZoom = true
        }
        
        if self.isBlockingAutoZoom == false{
            self.isZooming = true
            self.mapView.setCenter(location.coordinate, animated: true)
        }
        
        var accuracyRadius = 50.0
        if location.horizontalAccuracy > 0{
            if location.horizontalAccuracy > accuracyRadius{
                accuracyRadius = location.horizontalAccuracy
            }
        }
        if let accuracyRangeCircle = self.accuracyRangeCircle {
            self.mapView.removeOverlay(accuracyRangeCircle)

        }
        self.accuracyRangeCircle = MKCircle(center: location.coordinate, radius: accuracyRadius as CLLocationDistance)
        self.mapView.addOverlay(self.accuracyRangeCircle!)
        
        if self.userAnnotation != nil{
            self.mapView.removeAnnotation(self.userAnnotation!)
        }
        
        self.userAnnotation = UserAnnotation(coordinate: location.coordinate, title: "", subtitle: "")
        self.mapView.addAnnotation(self.userAnnotation!)
    }
    
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        if self.isZooming == true{
            self.isZooming = false
            self.isBlockingAutoZoom = false
        }else{
            self.isBlockingAutoZoom = true
            if let timer = self.zoomBlockingTimer{
                if timer.isValid{
                    timer.invalidate()
                }
            }
            self.zoomBlockingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false, block: { (Timer) in
                self.zoomBlockingTimer = nil
                self.isBlockingAutoZoom = false;
            })
        }
    }
    
    func showRouteOnMap(pickupCoordinate: CLLocationCoordinate2D, destinationCoordinate: CLLocationCoordinate2D) {

            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: pickupCoordinate, addressDictionary: nil))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destinationCoordinate, addressDictionary: nil))
            request.requestsAlternateRoutes = true
            request.transportType = .walking

            let directions = MKDirections(request: request)

            directions.calculate { [unowned self] response, error in
                guard let unwrappedResponse = response else { return }
                
                //for getting just one route
                if let route = unwrappedResponse.routes.first {
                    //show on map
                    self.navigationItem.rightBarButtonItem?.isEnabled = true
                    self.mapView.addOverlay(route.polyline)
                    //set the map area to show the route
                    self.mapView.setVisibleMapRect(route.polyline.boundingMapRect, edgePadding: UIEdgeInsets.init(top: 80.0, left: 20.0, bottom: 100.0, right: 20.0), animated: true)
                }

                //if you want to show multiple routes then you can get all routes in a loop in the following statement
                //for route in unwrappedResponse.routes {}
            }
        }
    
    func addAnnotationOnLocation(location:CLLocationCoordinate2D?){
        guard location != nil else{return}
        
        marker = MKPointAnnotation()
        marker.coordinate = location!
//        marker.title = "Prashant"
//        marker.subtitle = "I am comming"
        mapView.addAnnotation(marker)
        
        mapView.setRegion(MKCoordinateRegion(center: location!, latitudinalMeters: 100, longitudinalMeters: 100), animated: true)
    }
    
    func updateAnnotationWithLocation(location:CLLocationCoordinate2D?){
        guard location != nil else{return}
        CATransaction.begin()
        CATransaction.setAnimationDuration(2.0)
        marker.coordinate = location!
        CATransaction.commit()
        mapView.setRegion(MKCoordinateRegion(center: location!, latitudinalMeters: 100, longitudinalMeters: 100), animated: true)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation{
            return nil
        }else{
            let identifier = "UserAnnotation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            if annotationView != nil{
                annotationView!.annotation = annotation
            }else{
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            }
            annotationView!.canShowCallout = false
            annotationView!.image = self.userAnnotationImage
            
            return annotationView
        }
    }
    
    //this delegate function is for displaying the route overlay and styling it
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
//         let renderer = MKPolylineRenderer(overlay: overlay)
//         renderer.strokeColor = UIColor.red
//         renderer.lineWidth = 5.0
//         return renderer
        
        if overlay === self.accuracyRangeCircle{
            let circleRenderer = MKCircleRenderer(circle: overlay as! MKCircle)
            circleRenderer.fillColor = UIColor(white: 0.0, alpha: 0.25)
            circleRenderer.lineWidth = 0
            return circleRenderer
        }else{
            let polylineRenderer = MKPolylineRenderer(polyline: overlay as! MKPolyline)
            polylineRenderer.strokeColor = .green
            polylineRenderer.alpha = 1.0
            polylineRenderer.lineWidth = 5.0
            return polylineRenderer
        }
    }
    
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
