//
//  LocationPickerViewController.swift
//  LocationPicker
//
//  Created by Almas Sapargali on 7/29/15.
//  Copyright (c) 2015 almassapargali. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

 class LocationPickerViewController: UIViewController {
	struct CurrentLocationListener {
		let once: Bool
		let action: (CLLocation) -> ()
	}
    var searchCompleter = MKLocalSearchCompleter()

    // These are the results that are returned from the searchCompleter & what we are displaying
    // on the searchResultsTable
    var searchResults = [MKLocalSearchCompletion]()
	
	public var completion: ((Location?) -> ())?
	
	// region distance to be used for creation region when user selects place from search results
	public var resultRegionDistance: CLLocationDistance = 600
	
	/// default: true
	public var showCurrentLocationButton = true
	
	/// default: true
	public var showCurrentLocationInitially = true

    /// default: false
    /// Select current location only if `location` property is nil.
    public var selectCurrentLocationInitially = false
	
	/// see `region` property of `MKLocalSearchRequest`
	/// default: false
	public var useCurrentLocationAsHint = false
	
	/// default: "Search or enter an address"
	public var searchBarPlaceholder = "Search or enter an address"
	
	/// default: "Search History"
	public var searchHistoryLabel = "Search History"
    
    /// default: "Select"
    public var selectButtonTitle = "Select"
	
	public lazy var currentLocationButtonBackground: UIColor = {
		if let navigationBar = self.navigationController?.navigationBar,
			let barTintColor = navigationBar.barTintColor {
				return barTintColor
		} else { return .white }
	}()
    
    /// default: .minimal
    public var searchBarStyle: UISearchBar.Style = .minimal

	/// default: .default
	public var statusBarStyle: UIStatusBarStyle = .default

    @available(iOS 13.0, *)
    public lazy var searchTextFieldColor: UIColor = .clear
	
	public var mapType: MKMapType = .standard {
		didSet {
			if isViewLoaded {
				mapView.mapType = mapType
			}
		}
	}
	
	public var location: Location? {
		didSet {
			if isViewLoaded {
                DispatchQueue.main.async {
                    self.searchBar.text = self.location.flatMap({ $0.title }) ?? ""
                    self.updateAnnotation()
                }
				
			}
		}
	}
	
	static let SearchTermKey = "SearchTermKey"
	
	let historyManager = SearchHistoryManager()
	let locationManager = CLLocationManager()
	let geocoder = CLGeocoder()
	var localSearch: MKLocalSearch?
	var searchTimer: Timer?
	
	var currentLocationListeners: [CurrentLocationListener] = []
	
	var mapView: MKMapView!
	var locationButton: UIButton?
	
	lazy var results: LocationSearchResultsViewController = {
		let results = LocationSearchResultsViewController()
		results.onSelectLocation = { [weak self] in
            
//            let result = searchResults[indexPath.row]
                    let searchRequest = MKLocalSearch.Request(completion: $0)

                    let search = MKLocalSearch(request: searchRequest)
                    search.start { (response, error) in
                        guard let coordinate = response?.mapItems[0].placemark.coordinate else {
                            return
                        }

                        guard let name = response?.mapItems[0].name else {
                            return
                        }
                        guard let placemark = response?.mapItems[0].placemark else {
                            return
                        }
                        var locationObj = Location(name: name, placemark: placemark)
                        let lat = coordinate.latitude
                        let lon = coordinate.longitude
                        self?.selectedLocation(locationObj)

                        print(lat)
                        print(lon)
                                    print(name)

                    }
            
            
            
        }
		results.searchHistoryLabel = self.searchHistoryLabel
		return results
	}()

	lazy var searchController: UISearchController = {
		let search = UISearchController(searchResultsController: self.results)
		search.searchResultsUpdater = self
		search.hidesNavigationBarDuringPresentation = false
		return search
	}()
	
	lazy var searchBar: UISearchBar = {
		let searchBar = self.searchController.searchBar
		searchBar.searchBarStyle = self.searchBarStyle
		searchBar.placeholder = self.searchBarPlaceholder
        if #available(iOS 13.0, *) {
            searchBar.searchTextField.backgroundColor = searchTextFieldColor
        }
		return searchBar
	}()
	
	deinit {
		searchTimer?.invalidate()
		localSearch?.cancel()
		geocoder.cancelGeocode()
	}
	
	open override func loadView() {
		mapView = MKMapView(frame: UIScreen.main.bounds)
		mapView.mapType = mapType
		view = mapView
		
		if showCurrentLocationButton {
			let button = UIButton(frame: CGRect(x: 0, y: 0, width: 32, height: 32))
			button.backgroundColor = currentLocationButtonBackground
			button.layer.masksToBounds = true
			button.layer.cornerRadius = 16
			#if SWIFT_PACKAGE
			let bundle = Bundle.module
			#else
			let bundle = Bundle(for: LocationPickerViewController.self)
			#endif
			button.setImage(UIImage(named: "geolocation", in: bundle, compatibleWith: nil), for: UIControl.State())
			button.addTarget(self, action: #selector(LocationPickerViewController.currentLocationPressed),
			                 for: .touchUpInside)
			view.addSubview(button)
			locationButton = button
		}
	}
	
	open override func viewDidLoad() {
		super.viewDidLoad()

        if #available(iOS 13.0, *), let navigationController = navigationController {
            let appearance = navigationController.navigationBar.standardAppearance
            appearance.backgroundColor = navigationController.navigationBar.barTintColor
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
        }
		
		locationManager.delegate = self
		mapView.delegate = self
		searchBar.delegate = self
        
        searchCompleter.delegate = self
		// search
        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        } else {
            navigationItem.titleView = searchBar
            // http://stackoverflow.com/questions/32675001/uisearchcontroller-warning-attempting-to-load-the-view-of-a-view-controller/
            _ = searchController.view
        }
		definesPresentationContext = true
		
		// user location
		mapView.userTrackingMode = .none
		mapView.showsUserLocation = showCurrentLocationInitially || showCurrentLocationButton
		
		if useCurrentLocationAsHint {
			getCurrentLocation()
		}
	}
    
    open override func viewWillDisappear(_ animated: Bool) {
        // Resign first responder to avoid the search bar disappearing issue
        searchController.isActive = false
    }
    
	open override var preferredStatusBarStyle : UIStatusBarStyle {
		return statusBarStyle
	}
	
	var presentedInitialLocation = false
	
	open override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		if let button = locationButton {
			button.frame.origin = CGPoint(
				x: view.frame.width - button.frame.width - 16,
				y: view.frame.height - button.frame.height - 20
			)
		}
		
		// setting initial location here since viewWillAppear is too early, and viewDidAppear is too late
		if !presentedInitialLocation {
			setInitialLocation()
			presentedInitialLocation = true
		}
	}
	
	func setInitialLocation() {
		if let location = location {
			// present initial location if any
			self.location = location
			showCoordinates(location.coordinate, animated: false)
            return
		} else if showCurrentLocationInitially || selectCurrentLocationInitially {
            if selectCurrentLocationInitially {
                let listener = CurrentLocationListener(once: true) { [weak self] location in
                    if self?.location == nil { // user hasn't selected location still
                        self?.selectLocation(location: location)
                    }
                }
                currentLocationListeners.append(listener)
            }
			showCurrentLocation(false)
		}
	}
	
	func getCurrentLocation() {
		locationManager.requestWhenInUseAuthorization()
		locationManager.startUpdatingLocation()
	}
	
    @objc func currentLocationPressed() {
		showCurrentLocation()
	}
	
	func showCurrentLocation(_ animated: Bool = true) {
		let listener = CurrentLocationListener(once: true) { [weak self] location in
			self?.showCoordinates(location.coordinate, animated: animated)
		}
		currentLocationListeners.append(listener)
        getCurrentLocation()
	}
	
	func updateAnnotation() {
		mapView.removeAnnotations(mapView.annotations)
		if let location = location {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location.coordinate
            annotation.title = location.title
//            annotation.subtitle = location.su
			mapView.addAnnotation(annotation)
			//mapView.selectAnnotation(location, animated: true)
		}
	}
	
	func showCoordinates(_ coordinate: CLLocationCoordinate2D, animated: Bool = true) {
		let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: resultRegionDistance, longitudinalMeters: resultRegionDistance)
		mapView.setRegion(region, animated: animated)
	}

    func selectLocation(location: CLLocation) {
        // add point annotation to map
        let annotation = MKPointAnnotation()
        annotation.coordinate = location.coordinate
        mapView.addAnnotation(annotation)
        geocoder.cancelGeocode()
        geocoder.reverseGeocodeLocation(location) { response, error in
            if let error = error as NSError?, error.code != 10 { // ignore cancelGeocode errors
                // show error and remove annotation
                let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in }))
                self.present(alert, animated: true) {
                   // self.mapView.removeAnnotation(annotation)
                }
            } else if let placemark = response?.first {
                // get POI name from placemark if any
                let name = placemark.areasOfInterest?.first

                // pass user selected location too
                self.location = Location(name: name, location: location, placemark: placemark)
            }
        }
    }
     
}

//@available(iOS 9.3, *)
extension LocationPickerViewController: CLLocationManagerDelegate {
	public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.first else { return }
        currentLocationListeners.forEach { $0.action(location) }
		currentLocationListeners = currentLocationListeners.filter { !$0.once }
		manager.stopUpdatingLocation()
	}
}

// MARK: Searching

//@available(iOS 9.3, *)
extension LocationPickerViewController: UISearchResultsUpdating {
	public func updateSearchResults(for searchController: UISearchController) {
		guard let term = searchController.searchBar.text else { return }
		
		searchTimer?.invalidate()

		let searchTerm = term.trimmingCharacters(in: CharacterSet.whitespaces)
			
			searchTimer = Timer.scheduledTimer(timeInterval: 0.2,
				target: self, selector: #selector(LocationPickerViewController.searchFromTimer(_:)),
				userInfo: [LocationPickerViewController.SearchTermKey: searchTerm],
				repeats: false)
	}
	
    @objc func searchFromTimer(_ timer: Timer) {
		guard let userInfo = timer.userInfo as? [String: AnyObject],
			let term = userInfo[LocationPickerViewController.SearchTermKey] as? String
			else { return }
        searchCompleter.queryFragment = term
	}
	
	func showItemsForSearchResult(_ searchResult: [MKLocalSearchCompletion]) {
        print(searchResult)
        results.locations = searchResult
		results.isShowingHistory = false
		results.tableView.reloadData()
	}
	
	func selectedLocation(_ location: Location) {
		// dismiss search results
		dismiss(animated: true) {
			// set location, this also adds annotation
			self.location = location
			self.showCoordinates(location.coordinate)
			self.historyManager.addToHistory(location)
		}
	}
}

// MARK: Selecting location with gesture



//@available(iOS 9.3, *)
extension LocationPickerViewController : MKLocalSearchCompleterDelegate {
    // This method declares gets called whenever the searchCompleter has new search results
    // If you wanted to do any filter of the locations that are displayed on the the table view
    // this would be the place to do it.
    public func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        // Setting our searcResults variable to the results that the searchCompleter returned
       // searchResults = completer.results
        self.showItemsForSearchResult(completer.results)

        // Reload the tableview with our new searchResults
        results.tableView.reloadData()
    }

    // This method is called when there was an error with the searchCompleter
    public func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        // Error
    }
}

// MARK: MKMapViewDelegate


extension LocationPickerViewController: MKMapViewDelegate {
	 func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
		if annotation is MKUserLocation { return nil }
//        var pin = mapView.dequeueReusableAnnotationView(withIdentifier: "annotation") as? MKPinAnnotationView
         
         var pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")


//		let pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        if pin == nil {
            pin = MKPinAnnotationView(annotation: annotation, reuseIdentifier: "annotation")
        }
        else {
            pin.annotation = annotation
        }
         pin.pinTintColor = .purple
         pin.isDraggable = true
         pin.canShowCallout = true
         pin.animatesDrop = true
         pin.rightCalloutAccessoryView = selectLocationButton()
		return pin
	}
    
     func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        if newState == MKAnnotationView.DragState.ending {
            let droppedAt = view.annotation?.coordinate
            print(droppedAt.debugDescription)
            let location = CLLocation(latitude: (view.annotation?.coordinate.latitude)!, longitude: (view.annotation?.coordinate.longitude)!)
            
            geocoder.cancelGeocode()
            geocoder.reverseGeocodeLocation(location) { response, error in
                if let error = error as NSError?, error.code != 10 { // ignore cancelGeocode errors
                    // show error and remove annotation
                    let alert = UIAlertController(title: nil, message: error.localizedDescription, preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { _ in }))
                    self.present(alert, animated: true) {
                       // self.mapView.removeAnnotation(annotation)
                    }
                } else if let placemark = response?.first {
                    // get POI name from placemark if any
                    let name = placemark.areasOfInterest?.first
//                    let annotation = MKPointAnnotation()
//                    annotation.coordinate = view.annotation!.coordinate
//                    annotation.title = name
                    self.location = Location(name: name, location: location, placemark: placemark)

//                    mapView.addAnnotation(annotation)

                    
                    
                    // pass user selected location too
   //                 self.location = Location(name: name, location: location, placemark: placemark)
                }
            }
            
//            selectLocation(location: location)
        }
    }
    
//    public func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState)
//        {
//            if (newState == MKAnnotationView.DragState.ending)
//            {
//                let droppedAt = view.annotation?.coordinate
//                print("dropped at : ", droppedAt?.latitude ?? 0.0, droppedAt?.longitude ?? 0.0);
//                view.setDragState(.none, animated: true)
//            }
//            if (newState == .canceling )
//            {
//                view.setDragState(.none, animated: true)
//            }
//        }
	
	func selectLocationButton() -> UIButton {
		let button = UIButton(frame: CGRect(x: 0, y: 0, width: 70, height: 30))
		button.setTitle(selectButtonTitle, for: UIControl.State())
        if let titleLabel = button.titleLabel {
            let width = titleLabel.textRect(forBounds: CGRect(x: 0, y: 0, width: Int.max, height: 30), limitedToNumberOfLines: 1).width
            button.frame.size = CGSize(width: width, height: 30.0)
        }
		button.setTitleColor(view.tintColor, for: UIControl.State())
		return button
	}
	
	 func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
		completion?(location)
		if let navigation = navigationController, navigation.viewControllers.count > 1 {
			navigation.popViewController(animated: true)
		} else {
			presentingViewController?.dismiss(animated: true, completion: nil)
		}
	}
	
//	public func mapView(_ mapView: MKMapView, didAdd views: [MKAnnotationView]) {
//		let pins = mapView.annotations.filter { $0 is MKPinAnnotationView }
//		//assert(pins.count <= 1, "Only 1 pin annotation should be on map at a time")
//
//        if let userPin = views.first(where: { $0.annotation is MKUserLocation }) {
//            userPin.canShowCallout = true
//        }
//	}
    
     func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        print(#function)
    }
}

////@available(iOS 9.3, *)
//extension LocationPickerViewController: UIGestureRecognizerDelegate {
//    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
//        return true
//    }
//}

// MARK: UISearchBarDelegate

//@available(iOS 9.3, *)
extension LocationPickerViewController: UISearchBarDelegate {
	public func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
		// dirty hack to show history when there is no text in search bar
		// to be replaced later (hopefully)
		if let text = searchBar.text, text.isEmpty {
			searchBar.text = " "
		}
	}
	
	public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
		// remove location if user presses clear or removes text
		if searchText.isEmpty {
			location = nil
			searchBar.text = " "
		}
	}
}
