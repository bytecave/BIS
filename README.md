ByteCave Image Server, (c) 2019-2020 ByteCave. Usage under the MIT License.

ByteCave Image Server is an open-source mini webserver that sends a random image to your browser when a client sends any GET request. You provide a recursively processed folder containing the images to display. Those images are then shuffled and never repeated--on a per client connection basis--until all images have been displayed once. The process then repeats itself for subsequent image requests.

Instructions
===========================================================================
While image server networking is stopped:
> Click "Default Folder" button to add default images folder for new
  connections.
> Click on any image button to specify images folder for specified IP
  address or to remove button for that IP address.

While image server is running:
> Last displayed image displays on the surface of button associated with
  the IP address that requested the image.

> Click "Default Folder" to display name of default images folder.
> Click on any image button that is not grayed out to display grand total
  of images ever displayed for that IP address and path of the last
  displayed image.
> Hover over any image button that is not grayed out to see tooltip
  containing the information above.

Github home: https://github.com/bytecave/BIS
Contact: github@bytecave.net
