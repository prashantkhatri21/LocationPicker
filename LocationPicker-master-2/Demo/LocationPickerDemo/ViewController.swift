//
//  ViewController.swift
//  LocationPickerDemo
//
//  Created by Almas Sapargali on 7/29/15.
//  Copyright (c) 2015 almassapargali. All rights reserved.
//

import UIKit
import LocationPicker
import CoreLocation
import MapKit

@available(iOS 9.3, *)
class ViewController: UIViewController {
    
    @IBOutlet weak var destinationButton: UIButton!
    @IBOutlet weak var sourceButton: UIButton!
    var sourceLocation: Location? {
		didSet {
            sourceButton.setTitle(sourceLocation.flatMap({ $0.title }) ?? "No location selected", for: .normal)
		}
	}
    var destinationLocation: Location? {
        didSet {
            destinationButton.setTitle(destinationLocation.flatMap({ $0.title }) ?? "No location selected", for: .normal)
        }
    }
	
	override func viewDidLoad() {
		super.viewDidLoad()
		sourceLocation = nil
        destinationLocation = nil

	}
	
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let locationPicker = segue.destination as! LocationPickerViewController
        locationPicker.showCurrentLocationButton = true
        locationPicker.useCurrentLocationAsHint = true
        locationPicker.selectCurrentLocationInitially = true

		if segue.identifier == "Source" {
            locationPicker.location = sourceLocation
			locationPicker.completion = { self.sourceLocation = $0 }
		}
        else  {
            locationPicker.location = destinationLocation
            locationPicker.completion = { self.destinationLocation = $0 }
        }
	}
    @IBAction func clickRoute(_ sender: Any) {
        let routeVC = self.storyboard?.instantiateViewController(withIdentifier: "RouteVC") as! RouteVC
        routeVC.sourceLocation = sourceLocation
        routeVC.destinationLocation = destinationLocation
        self.navigationController?.pushViewController(routeVC, animated: true)

      }

//func queryLocationOfSubsetOfUsersInRadius() {
//
//    let dispatchGroup = DispatchGroup()
//
//    for user in subsetOfUsersInRadius {
//
//        dispatchGroup.enter()
//
//        let userId = user.userId
//
//        let geoLocationsRef = Database.database().reference()
//            .child("geoLocations")
//            .child(userId)
//            .child("l")
//
//        geoLocationsRef.observeSingleEvent(of: .value, with: { (snapshot) in
//
//            // this user may have deleted their location
//            if !snapshot.exists() {
//                dispatchGroup.leave()
//                return
//            }
//
//            guard let arr = snapshot.value as? [CLLocationDegrees] else {
//                dispatchGroup.leave()
//                return
//            }
//
//            if arr.count > 1 {
//
//                let latitude = arr[0]
//                print(latitude)
//
//                let longitude = arr[1]
//                print(longitude)
//
//                // do whatever with the latitude and longitude
//            }
//
//            dispatchGroup.leave()
//        })
//    }
//
//    dispatchGroup.notify(queue: .global(qos: .background)) {
//
//        // now animate the annotation from the user's inital old location (if they moved) on the mapView to their new location on the mapView. It's supposed to look like Uber's cars moving. Happens on main thread
//    }
//}

}
