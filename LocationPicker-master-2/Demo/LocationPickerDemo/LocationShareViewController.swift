//
//  LocationShareViewController.swift
//  mapUpdate
//
//  Created by Prashant Kaushik on 05/06/19.
//  Copyright © 2019 Prashant Kaushik. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation
import Firebase


class LocationShareViewController: UIViewController , MKMapViewDelegate{
    @IBOutlet weak var mapView: MKMapView!
    var locationManager:CLLocationManager!
    var location:CLLocation!
    var locationDataArray = [CLLocation]()

    var marker:MKPointAnnotation!
    var hunterReference:DatabaseReference!
    var adminRef:DatabaseReference!

    var userAnnotationImage: UIImage?
    var userAnnotation: UserAnnotation?
    var accuracyRangeCircle: MKCircle?
    var polyline: MKPolyline?
    var isZooming: Bool?
    var isBlockingAutoZoom: Bool?
    var zoomBlockingTimer: Timer?
    var didInitialZoom: Bool?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupLocationManager()
        adminRef = Database.database().reference().child(FirebasePaths.location.rawValue).child(FirebasePaths.Admin.rawValue)
        hunterReference = Database.database().reference().child(FirebasePaths.location.rawValue).child(FirebasePaths.Hunter.rawValue)

        addRouteLocationUpdateObserverforAdmin()
        // Do any additional setup after loading the view.
    }
    
    func setupLocationManager(){
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 5.0
        locationManager.requestWhenInUseAuthorization()
        locationManager.pausesLocationUpdatesAutomatically = true
    }
    
    func addRouteLocationUpdateObserverforAdmin(){
        adminRef.observeSingleEvent(of: .value) {[weak self] (snapShot) in
            guard let self = self else{return}
            
            if let value = snapShot.value as? NSDictionary{
                guard let sourceDict = value[FirebasePaths.Source.rawValue] as? NSDictionary else {
                    return
                }
                guard let destDict = value[FirebasePaths.Destination.rawValue] as? NSDictionary else {
                    return
                }
                guard let sourcelat = sourceDict["lat"] ,let sourcelong = sourceDict["long"], let destlat = destDict["lat"] ,let destlong = destDict["long"] else  {return}
                
                let sourcelocation = CLLocation(latitude: sourcelat as! CLLocationDegrees, longitude: sourcelong as! CLLocationDegrees)
                let destlocation = CLLocation(latitude: destlat as! CLLocationDegrees, longitude: destlong as! CLLocationDegrees)

                self.showRouteOnMap(pickupCoordinate: sourcelocation.coordinate, destinationCoordinate: destlocation.coordinate)

                print("source location latitude is \(sourcelocation) and destination longitute is \(destlocation)")
            }
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
   
    
    //this delegate function is for displaying the route overlay and styling it
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
         let renderer = MKPolylineRenderer(overlay: overlay)
         renderer.strokeColor = UIColor.red
         renderer.lineWidth = 5.0
         return renderer
    }

}

extension LocationShareViewController:CLLocationManagerDelegate{
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard locations.count != 0 else{return}
        self.locationDataArray.append(locations.last!)

        self.updatePolylines()
       // self.zoomTo(location: locations.last)
        if mapView.annotations.count == 0{
            addAnnotationOnLocation(location: locations.last?.coordinate)
        }else{
            updateAnnotationWithLocation(location: locations.last?.coordinate)
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
    
    func addAnnotationOnLocation(location:CLLocationCoordinate2D?){
        guard location != nil else{return}
        marker = MKPointAnnotation()
        marker.coordinate = location!
        marker.title = "Prashant"
        marker.subtitle = "I am comming"
        mapView.addAnnotation(marker)
        
        mapView.setRegion(MKCoordinateRegion(center: location!, latitudinalMeters: 100, longitudinalMeters: 100), animated: true)
        
        updateLocationOnFirebase(location: location!)
    }
    
    func updateAnnotationWithLocation(location:CLLocationCoordinate2D?){
        guard location != nil else{return}
        CATransaction.begin()
        CATransaction.setAnimationDuration(2.0)
        marker.coordinate = location!
        CATransaction.commit()
        
        updateLocationOnFirebase(location: location!)
        
        mapView.setRegion(MKCoordinateRegion(center: location!, latitudinalMeters: 100, longitudinalMeters: 100), animated: true)
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse{
            locationManager.startUpdatingLocation()
        }
    }
    
    
    func updateLocationOnFirebase(location:CLLocationCoordinate2D){
        let lat = location.latitude
        let long = location.longitude
        let value = ["lat":lat,"long":long]
        hunterReference.setValue(value) { (error, reference) in
            if error == nil {
                print("location successfully updated")
            }
        }
    }
    
}
