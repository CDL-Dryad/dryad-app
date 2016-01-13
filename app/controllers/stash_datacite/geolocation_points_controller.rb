require_dependency 'stash_datacite/application_controller'

module StashDatacite
  class GeolocationPointsController < ApplicationController
    before_action :set_geolocation_point, only: [:edit, :update, :destroy]

    # GET /geolocation_points/1/edit
    # def edit
    # end

    # POST /geolocation_points
    def create
      @geolocation_points = GeolocationPoint.where(resource_id: geolocation_point_params[:resource_id])
      @geolocation_places = GeolocationPlace.where(resource_id: geolocation_point_params[:resource_id])
      @geolocation_point = GeolocationPoint.new(geolocation_point_params)
      respond_to do |format|
        if @geolocation_point.save
          format.js
        else
          format.html { render :new }
        end
      end
    end

    # PATCH/PUT /geolocation_points/1
    # def update
    #   if @geolocation_point.update(geolocation_point_params)
    #     redirect_to @geolocation_point, notice: 'Geolocation point was successfully updated.'
    #   else
    #     render :edit
    #   end
    # end

    # DELETE /geolocation_points/1
    def destroy
      @geolocation_point.destroy
      redirect_to geolocation_points_url, notice: 'Geolocation point was successfully destroyed.'
    end

    private

    # Use callbacks to share common setup or constraints between actions.
    def set_geolocation_point
      @geolocation_point = GeolocationPoint.find(geolocation_point_params[:id])
    end

    # Only allow a trusted parameter "white list" through.
    def geolocation_point_params
      params.require(:geolocation_point).permit(:latitude, :longitude, :resource_id)
    end
  end
end
