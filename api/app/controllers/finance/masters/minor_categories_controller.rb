# frozen_string_literal: true

module Finance
  module Masters
    class MinorCategoriesController < ApplicationController
      def new
        @minor_category = MinorCategory.new
        @majors = MajorCategory.order(:kind, :name)
      end

      def create
        @minor_category = MinorCategory.new(minor_category_params)
        @majors = MajorCategory.order(:kind, :name)
        if @minor_category.save
          redirect_to finance_masters_path(tab: "categories"), notice: "小カテゴリを追加しました。"
        else
          flash.now[:alert] = @minor_category.errors.full_messages.join(" ")
          render :new, status: :unprocessable_entity
        end
      end

      def edit
        @minor_category = MinorCategory.find(params[:id])
        @majors = MajorCategory.order(:kind, :name)
      end

      def update
        @minor_category = MinorCategory.find(params[:id])
        @majors = MajorCategory.order(:kind, :name)
        if @minor_category.update(minor_category_params)
          redirect_to finance_masters_path(tab: "categories"), notice: "小カテゴリを更新しました。"
        else
          flash.now[:alert] = @minor_category.errors.full_messages.join(" ")
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        minor = MinorCategory.find(params[:id])
        minor.destroy!
        redirect_to finance_masters_path(tab: "categories"), notice: "小カテゴリを削除しました。"
      rescue ActiveRecord::DeleteRestrictionError
        redirect_to finance_masters_path(tab: "categories"), alert: "支出または収入が紐づいているため削除できません。"
      end

      private

      def minor_category_params
        params.expect(minor_category: [ :major_category_id, :name ])
      end
    end
  end
end
