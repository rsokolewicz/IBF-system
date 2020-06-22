import { Injectable } from '@angular/core';

export class Layer {
  type: LayerType;
  id: string;
  active: boolean;
}
export enum LayerType {
  point = 'point',
  pixel = 'pixel',
  shape = 'shape',
}

@Injectable({
  providedIn: 'root',
})
export class MapService {
  public state: any = {
    layers: [
      {
        type: LayerType.point,
        id: 'water-stations',
        active: true,
      },
      {
        type: LayerType.pixel,
        id: 'flood-extent',
        active: false,
      },
      {
        type: LayerType.shape,
        id: 'admin-boundries-level-1',
        active: true,
      },
    ] as Layer[],
  };

  constructor() {}

}
